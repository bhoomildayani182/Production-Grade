#!/bin/bash

# Docker Swarm Manager Setup Script
# This script installs Docker, initializes Swarm, and sets up the manager node

set -e

# Variables
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
LOG_FILE="/var/log/docker-swarm-setup.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Docker Swarm Manager setup for project: $PROJECT_NAME"

# Update system packages
log "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install required packages
log "Installing required packages..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
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

# Install Docker Compose (standalone)
log "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Wait for Docker to be ready
log "Waiting for Docker to be ready..."
sleep 10

# Initialize Docker Swarm
log "Initializing Docker Swarm..."
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
docker swarm init --advertise-addr $PRIVATE_IP

# Get join tokens and save them
log "Saving Swarm join tokens..."
WORKER_TOKEN=$(docker swarm join-token -q worker)
MANAGER_TOKEN=$(docker swarm join-token -q manager)

# Save tokens to files for later use
echo $WORKER_TOKEN > /tmp/worker-token
echo $MANAGER_TOKEN > /tmp/manager-token
echo $PRIVATE_IP > /tmp/manager-ip

# Create swarm network for applications
log "Creating overlay network for applications..."
docker network create --driver overlay --attachable app-network

# Create directories for application deployment
log "Creating application directories..."
mkdir -p /opt/docker-swarm/{traefik,app,logs}
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

# Create systemd service for Swarm monitoring
log "Creating Swarm monitoring service..."
cat > /etc/systemd/system/swarm-monitor.service << EOF
[Unit]
Description=Docker Swarm Monitor
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=ubuntu
ExecStart=/bin/bash -c 'while true; do docker node ls >> /var/log/swarm-monitor.log 2>&1; sleep 60; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable swarm-monitor
systemctl start swarm-monitor

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
                        "log_stream_name": "manager-setup"
                    }
                ]
            }
        }
    }
}
EOF

# Signal completion
log "Docker Swarm Manager setup completed successfully!"
echo "SETUP_COMPLETE" > /tmp/setup-status

# Create a simple health check script
cat > /opt/docker-swarm/health-check.sh << 'EOF'
#!/bin/bash
# Simple health check for Docker Swarm manager

if docker info | grep -q "Swarm: active"; then
    echo "Swarm is active"
    exit 0
else
    echo "Swarm is not active"
    exit 1
fi
EOF

chmod +x /opt/docker-swarm/health-check.sh

log "Manager node setup script completed successfully!"
