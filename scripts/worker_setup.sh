#!/bin/bash

# Docker Swarm Worker Setup Script
# This script installs Docker and joins the worker node to the Swarm cluster

set -e

# Variables
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
MANAGER_IP="${manager_ip}"
LOG_FILE="/var/log/docker-swarm-setup.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Docker Swarm Worker setup for project: $PROJECT_NAME"

# Update system packages
log "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install required packages
log "Installing required packages..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    netcat-openbsd \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    jq \
    htop \
    vim

# Install Docker
log "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
log "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Set up SSH key for inter-node communication
log "Setting up SSH keys for inter-node communication..."
# Ensure SSH directory exists with proper permissions
mkdir -p /home/ubuntu/.ssh
chown ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh

# Copy the AWS key pair private key to ubuntu user's SSH directory
# The key is automatically placed in /home/ubuntu/.ssh/ by AWS
if [ -f /home/ubuntu/.ssh/authorized_keys ]; then
    log "Found authorized_keys file"
    # Extract the key name from the authorized_keys comment (usually the key pair name)
    KEY_NAME=$(grep -o 'aws-key-[^[:space:]]*' /home/ubuntu/.ssh/authorized_keys | head -1 || echo "aws-key")
    log "Using key name: $KEY_NAME"
else
    log "Warning: No authorized_keys file found"
fi

# Create SSH config to use the AWS key pair and disable strict host key checking
cat > /home/ubuntu/.ssh/config << EOF
Host 10.*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    IdentitiesOnly yes
    PasswordAuthentication no
EOF

chown ubuntu:ubuntu /home/ubuntu/.ssh/config
chmod 600 /home/ubuntu/.ssh/config

# Ensure the ubuntu user can access the SSH agent
log "Setting up SSH agent for ubuntu user..."
sudo -u ubuntu ssh-add -l 2>/dev/null || log "No SSH keys in agent (this is normal)"

# Install Docker Compose (standalone)
log "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Wait for Docker to be ready
log "Waiting for Docker to be ready..."
sleep 10

# Test SSH connectivity to manager first
log "Testing SSH connectivity to manager node..."
SSH_TEST_COUNT=0
MAX_SSH_RETRIES=5

while [ $SSH_TEST_COUNT -lt $MAX_SSH_RETRIES ]; do
    log "Testing SSH connection to manager (attempt $((SSH_TEST_COUNT + 1))/$MAX_SSH_RETRIES)..."
    
    # Test basic SSH connectivity
    if sudo -u ubuntu ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes ubuntu@$MANAGER_IP "echo 'SSH connection successful'" 2>/dev/null; then
        log "SSH connection to manager successful"
        break
    else
        log "SSH connection failed, retrying in 15 seconds..."
        sleep 15
        SSH_TEST_COUNT=$((SSH_TEST_COUNT + 1))
    fi
done

if [ $SSH_TEST_COUNT -eq $MAX_SSH_RETRIES ]; then
    log "ERROR: Failed to establish SSH connection to manager after $MAX_SSH_RETRIES attempts"
    log "Please check:"
    log "1. Security groups allow SSH (port 22) between VPC subnets"
    log "2. Both nodes are using the same AWS key pair"
    log "3. Manager node is accessible and running"
    exit 1
fi

# Wait for manager to be ready and get join token
log "Waiting for manager node to be ready..."
RETRY_COUNT=0
MAX_RETRIES=10

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    log "Attempting to retrieve join token from manager (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)..."
    
    # First try to get the worker token from the file on manager node
    log "Trying to read worker token from file on manager node..."
    WORKER_TOKEN=$(sudo -u ubuntu ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$MANAGER_IP "cat /tmp/worker-token 2>/dev/null" 2>/dev/null || echo "")
    
    if [ ! -z "$WORKER_TOKEN" ]; then
        log "Successfully retrieved worker token from file on manager"
        break
    fi
    
    # If file doesn't exist or is empty, fall back to docker command
    log "Token file not found or empty, trying docker command..."
    WORKER_TOKEN=$(sudo -u ubuntu ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$MANAGER_IP "sudo docker swarm join-token -q worker" 2>/dev/null || echo "")
    
    if [ ! -z "$WORKER_TOKEN" ]; then
        log "Successfully retrieved worker token from docker command"
        break
    fi
    
    log "Failed to retrieve token, retrying in 30 seconds..."
    sleep 30
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ -z "$WORKER_TOKEN" ]; then
    log "ERROR: Failed to retrieve worker token from manager after $MAX_RETRIES attempts"
    exit 1
fi

# Join the Swarm as a worker
log "Joining Docker Swarm as worker..."
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
log "Worker IP: $PRIVATE_IP, Manager IP: $MANAGER_IP"
log "Join command: docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"

# Test connectivity to manager first
log "Testing connectivity to manager on port 2377..."
if nc -z $MANAGER_IP 2377; then
    log "Successfully connected to manager on port 2377"
else
    log "ERROR: Cannot connect to manager on port 2377"
    log "Checking if manager IP is reachable..."
    ping -c 3 $MANAGER_IP || log "Manager IP not reachable"
    exit 1
fi

# Join the swarm
docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377

# Verify join was successful
log "Verifying Swarm membership..."
if docker info | grep -q "Swarm: active"; then
    log "Successfully joined Docker Swarm as worker"
else
    log "ERROR: Failed to join Docker Swarm"
    exit 1
fi

# Create directories for application deployment
log "Creating application directories..."
mkdir -p /opt/docker-swarm/{app,logs}
chown -R ubuntu:ubuntu /opt/docker-swarm

# Set up log rotation
log "Setting up log rotation..."
cat > /etc/logrotate.d/docker-swarm << EOF
/var/log/docker-swarm-setup.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 root root
}
EOF

# Install AWS CLI for potential S3 integration
log "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Set up CloudWatch agent (optional)
log "Setting up CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Create CloudWatch config
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/docker-swarm-setup.log",
                        "log_group_name": "/aws/ec2/docker-swarm/$PROJECT_NAME",
                        "log_stream_name": "worker-setup-$(hostname)"
                    }
                ]
            }
        }
    }
}
EOF

# Signal completion
log "Docker Swarm Worker setup completed successfully!"
echo "SETUP_COMPLETE" > /tmp/setup-status

# Create a simple health check script
cat > /opt/docker-swarm/health-check.sh << 'EOF'
#!/bin/bash
# Simple health check for Docker Swarm worker

if docker info | grep -q "Swarm: active"; then
    echo "Swarm is active"
    exit 0
else
    echo "Swarm is not active"
    exit 1
fi
EOF

chmod +x /opt/docker-swarm/health-check.sh

log "Worker node setup script completed successfully!"
