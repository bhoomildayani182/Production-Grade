#!/bin/bash

# Docker Swarm Cluster Deployment Script
# This script deploys the infrastructure and application using Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Initialize Terraform
init_terraform() {
    log "Initializing Terraform..."
    terraform init
    success "Terraform initialized"
}

# Validate Terraform configuration
validate_terraform() {
    log "Validating Terraform configuration..."
    terraform validate
    success "Terraform configuration is valid"
}

# Plan Terraform deployment
plan_terraform() {
    log "Planning Terraform deployment..."
    terraform plan -out=tfplan
    success "Terraform plan created"
}

# Apply Terraform configuration
apply_terraform() {
    log "Applying Terraform configuration..."
    terraform apply tfplan
    success "Infrastructure deployed successfully"
}

# Get outputs
get_outputs() {
    log "Getting deployment outputs..."
    
    MANAGER_IP=$(terraform output -raw swarm_manager_public_ip)
    LOAD_BALANCER_DNS=$(terraform output -raw load_balancer_dns)
    APPLICATION_URL=$(terraform output -raw application_url)
    
    success "Manager IP: $MANAGER_IP"
    success "Load Balancer DNS: $LOAD_BALANCER_DNS"
    success "Application URL: $APPLICATION_URL"
}

# Deploy application to Swarm
deploy_application() {
    log "Deploying application to Docker Swarm..."
    
    # Copy application files to manager node
    log "Copying application files to manager node..."
    scp -i docker-swarm-key.pem -r app/ ubuntu@$MANAGER_IP:/opt/docker-swarm/
    
    # Deploy the stack
    log "Deploying Docker stack..."
    ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP << 'EOF'
        cd /opt/docker-swarm/app
        
        # Create Traefik network if it doesn't exist
        docker network create --driver overlay traefik-public || true
        
        # Deploy the stack
        docker stack deploy -c docker-compose.yml swarm-app
        
        # Wait for services to be ready
        echo "Waiting for services to be ready..."
        sleep 30
        
        # Check service status
        docker service ls
EOF
    
    success "Application deployed to Docker Swarm"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check if services are running
    ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP << 'EOF'
        echo "Checking service status..."
        docker service ls
        
        echo "Checking node status..."
        docker node ls
        
        echo "Checking stack status..."
        docker stack ps swarm-app
EOF
    
    # Test application endpoint
    log "Testing application endpoint..."
    sleep 60  # Wait for load balancer to be ready
    
    if curl -f -s "$APPLICATION_URL" > /dev/null; then
        success "Application is accessible at: $APPLICATION_URL"
    else
        warning "Application might not be ready yet. Please check manually: $APPLICATION_URL"
    fi
}

# Main deployment function
main() {
    log "Starting Docker Swarm cluster deployment..."
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        warning "terraform.tfvars not found. Please copy terraform.tfvars.example to terraform.tfvars and configure it."
        exit 1
    fi
    
    check_prerequisites
    init_terraform
    validate_terraform
    plan_terraform
    
    # Ask for confirmation
    echo
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled."
        exit 0
    fi
    
    apply_terraform
    get_outputs
    
    # Wait for instances to be ready
    log "Waiting for instances to be ready..."
    sleep 120
    
    deploy_application
    verify_deployment
    
    success "Deployment completed successfully!"
    echo
    echo "=== Deployment Summary ==="
    echo "Manager IP: $MANAGER_IP"
    echo "Load Balancer DNS: $LOAD_BALANCER_DNS"
    echo "Application URL: $APPLICATION_URL"
    echo "SSH to manager: ssh -i docker-swarm-key.pem ubuntu@$MANAGER_IP"
    echo
    echo "To destroy the infrastructure, run: ./destroy.sh"
}

# Run main function
main "$@"
