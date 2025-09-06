# Docker Swarm Infrastructure Deployment Guide

This guide walks you through deploying the Docker Swarm cluster step-by-step.

## 📋 Prerequisites Checklist

- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] Git repository cloned
- [ ] Domain name (optional, for SSL)

## 🚀 Step-by-Step Deployment

### Step 1: AWS Configuration
```bash
# Configure AWS credentials
aws configure

# Verify configuration
aws sts get-caller-identity
```

**Expected Output:**
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### Step 2: Configure Terraform Variables
```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars  # or use your preferred editor
```

**Required Configuration:**
```hcl
# Basic Configuration
aws_region = "us-west-2"
project_name = "my-swarm-cluster"
instance_type = "t3.medium"

# Security (IMPORTANT: Restrict in production)
allowed_cidr_blocks = ["YOUR_IP/32"]  # Replace with your IP

# Optional: DNS Configuration
domain_name = "yourdomain.com"
enable_route53 = true
enable_ssl = true
```

### Step 3: Initialize Terraform
```bash
terraform init
```

**What Terraform Does:**
1. Downloads AWS provider (~50MB)
2. Creates `.terraform/` directory
3. Initializes state backend
4. Creates dependency lock file

**Expected Output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
Terraform has been successfully initialized!
```

### Step 4: Validate Configuration
```bash
terraform validate
```

**Expected Output:**
```
Success! The configuration is valid.
```

### Step 5: Plan Deployment
```bash
terraform plan -out=tfplan
```

**What Terraform Shows:**
- Resources to be created (should be ~25-30 resources)
- No resources to change or destroy (first deployment)
- Estimated cost and time

**Key Resources to Verify:**
- ✅ 1 VPC with subnets
- ✅ 1 Manager + 2 Worker instances
- ✅ Security groups
- ✅ Load balancer
- ✅ SSH key pair

### Step 6: Deploy Infrastructure
```bash
terraform apply tfplan
```

**Deployment Timeline:**
- **0-2 minutes**: VPC, subnets, security groups
- **2-5 minutes**: EC2 instances launching
- **5-8 minutes**: Load balancer creation
- **8-12 minutes**: Instance initialization (Docker installation)
- **12-15 minutes**: Swarm cluster formation

**Expected Final Output:**
```
Apply complete! Resources: 28 added, 0 changed, 0 destroyed.

Outputs:
application_url = "http://your-alb-dns-name.us-west-2.elb.amazonaws.com"
load_balancer_dns = "your-alb-dns-name.us-west-2.elb.amazonaws.com"
ssh_command_manager = "ssh -i docker-swarm-key.pem ubuntu@1.2.3.4"
swarm_manager_public_ip = "1.2.3.4"
```

### Step 7: Verify Deployment
```bash
# Test SSH connection to manager
ssh -i docker-swarm-key.pem ubuntu@$(terraform output -raw swarm_manager_public_ip)

# Check Swarm status
docker node ls
docker service ls
```

**Expected Swarm Output:**
```
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS
abc123 *   ip-10-0-1-100      Ready     Active         Leader
def456     ip-10-0-10-200     Ready     Active         
ghi789     ip-10-0-20-201     Ready     Active         
```

### Step 8: Deploy Application Stack
```bash
# Copy application files to manager
scp -i docker-swarm-key.pem -r app/ ubuntu@$(terraform output -raw swarm_manager_public_ip):/opt/docker-swarm/

# SSH to manager and deploy
ssh -i docker-swarm-key.pem ubuntu@$(terraform output -raw swarm_manager_public_ip)

# On manager node:
cd /opt/docker-swarm/app
docker network create --driver overlay traefik-public
docker stack deploy -c docker-compose.yml swarm-app
```

### Step 9: Test Application
```bash
# Get application URL
terraform output application_url

# Test endpoints
curl http://your-load-balancer-dns/
curl http://your-load-balancer-dns/api/health
```

## 🔍 File Execution Details

### Terraform File Processing Order

1. **`main.tf`** - Providers and data sources
   ```hcl
   # Sets up AWS provider
   # Defines Ubuntu AMI data source
   # Configures availability zones
   ```

2. **`variables.tf`** - Variable definitions
   ```hcl
   # Defines all configurable parameters
   # Sets default values
   # Specifies variable types
   ```

3. **`vpc.tf`** - Network foundation
   ```hcl
   # Creates VPC (10.0.0.0/16)
   # Public subnets (10.0.1.0/24, 10.0.2.0/24)
   # Private subnets (10.0.10.0/24, 10.0.20.0/24)
   # Internet Gateway, NAT Gateways, Route Tables
   ```

4. **`security.tf`** - Security groups
   ```hcl
   # Manager security group (SSH, HTTP, HTTPS, Swarm ports)
   # Worker security group (Swarm communication only)
   # ALB security group (HTTP/HTTPS from internet)
   ```

5. **`key_pair.tf`** - SSH key management
   ```hcl
   # Generates RSA 4096-bit key pair
   # Creates AWS key pair resource
   # Saves private key locally
   ```

6. **`user_data.tf`** - Instance initialization
   ```hcl
   # Templates for manager and worker setup scripts
   # Passes variables to shell scripts
   ```

7. **`ec2.tf`** - Compute instances
   ```hcl
   # Manager instance in public subnet
   # Worker instances in private subnets
   # EBS volumes with encryption
   # Elastic IP for manager
   ```

8. **`load_balancer.tf`** - Load balancing
   ```hcl
   # Application Load Balancer
   # Target groups for HTTP/HTTPS
   # Health checks configuration
   # Listeners and routing rules
   ```

9. **`ssl.tf`** - SSL certificates
   ```hcl
   # ACM certificate request
   # DNS validation records
   # Certificate validation
   ```

10. **`route53.tf`** - DNS configuration
    ```hcl
    # A record pointing to load balancer
    # CNAME for www subdomain
    ```

11. **`outputs.tf`** - Output values
    ```hcl
    # IP addresses, DNS names
    # SSH commands
    # Application URLs
    ```

## 🛠️ Terraform Commands Reference

### Core Commands
```bash
# Initialize project
terraform init

# Validate syntax
terraform validate

# Format code
terraform fmt

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List resources
terraform state list

# Get outputs
terraform output

# Destroy infrastructure
terraform destroy
```

### Useful Commands
```bash
# Plan with variable file
terraform plan -var-file="production.tfvars"

# Apply specific resource
terraform apply -target=aws_instance.swarm_manager

# Import existing resource
terraform import aws_instance.example i-1234567890abcdef0

# Refresh state
terraform refresh

# Show specific output
terraform output swarm_manager_public_ip
```

## 🔧 Troubleshooting

### Common Issues

**Issue**: `terraform init` fails
```bash
# Solution: Check internet connection and AWS credentials
aws sts get-caller-identity
```

**Issue**: `terraform plan` shows permission errors
```bash
# Solution: Ensure AWS user has required permissions
# Required: EC2, VPC, IAM, Route53, ACM permissions
```

**Issue**: EC2 instances fail to launch
```bash
# Solution: Check AWS service limits
aws ec2 describe-account-attributes --attribute-names max-instances
```

**Issue**: SSH connection fails
```bash
# Solution: Check security group rules and key permissions
chmod 600 docker-swarm-key.pem
```

**Issue**: Application not accessible
```bash
# Solution: Check load balancer health checks
aws elbv2 describe-target-health --target-group-arn <arn>
```

## 📊 Resource Dependencies

```
VPC
├── Internet Gateway
├── Subnets
│   ├── Public Subnets
│   └── Private Subnets
├── Route Tables
├── NAT Gateways
└── Security Groups
    └── EC2 Instances
        ├── Manager (Public)
        └── Workers (Private)
            └── Load Balancer
                ├── Target Groups
                └── Listeners
                    └── SSL Certificate
                        └── Route53 Records
```

This dependency chain ensures resources are created in the correct order automatically by Terraform.
