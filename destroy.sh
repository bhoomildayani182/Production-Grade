#!/bin/bash

# Docker Swarm Cluster Destruction Script
# This script safely destroys the infrastructure created by Terraform

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

# Clean up Docker Swarm services
cleanup_swarm() {
    log "Cleaning up Docker Swarm services..."
    
    if [ -f "docker-swarm-key.pem" ]; then
        MANAGER_IP=$(terraform output -raw swarm_manager_public_ip 2>/dev/null || echo "")
        
        if [ ! -z "$MANAGER_IP" ]; then
            log "Removing Docker stack from manager node..."
            ssh -i docker-swarm-key.pem -o ConnectTimeout=10 ubuntu@$MANAGER_IP << 'EOF' || true
                # Remove the stack
                docker stack rm swarm-app || true
                
                # Wait for services to be removed
                sleep 30
                
                # Remove unused volumes and networks
                docker system prune -f || true
                docker volume prune -f || true
                docker network prune -f || true
EOF
            success "Docker stack removed"
        else
            warning "Could not get manager IP, skipping Docker cleanup"
        fi
    else
        warning "SSH key not found, skipping Docker cleanup"
    fi
}

# Destroy Terraform infrastructure
destroy_terraform() {
    log "Destroying Terraform infrastructure..."
    
    # Check if Terraform state exists
    if [ ! -f "terraform.tfstate" ]; then
        warning "No Terraform state found. Nothing to destroy."
        return
    fi
    
    # Show what will be destroyed
    log "Planning destruction..."
    terraform plan -destroy
    
    echo
    warning "This will destroy ALL infrastructure including:"
    warning "- EC2 instances"
    warning "- VPC and networking components"
    warning "- Load balancers"
    warning "- Security groups"
    warning "- All data will be lost!"
    echo
    
    read -p "Are you sure you want to destroy the infrastructure? Type 'yes' to confirm: " -r
    if [[ $REPLY != "yes" ]]; then
        log "Destruction cancelled."
        exit 0
    fi
    
    # Destroy infrastructure
    terraform destroy -auto-approve
    success "Infrastructure destroyed successfully"
}

# Clean up local files
cleanup_local() {
    log "Cleaning up local files..."
    
    # Remove Terraform files
    rm -f tfplan terraform.tfstate.backup
    
    # Remove SSH key (ask for confirmation)
    if [ -f "docker-swarm-key.pem" ]; then
        read -p "Remove SSH key file (docker-swarm-key.pem)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f docker-swarm-key.pem
            success "SSH key removed"
        fi
    fi
    
    success "Local cleanup completed"
}

# Main destruction function
main() {
    log "Starting infrastructure destruction..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed."
        exit 1
    fi
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        log "Initializing Terraform..."
        terraform init
    fi
    
    cleanup_swarm
    destroy_terraform
    cleanup_local
    
    success "Destruction completed successfully!"
    echo
    echo "All infrastructure has been destroyed."
    echo "You can safely delete this directory if you no longer need it."
}

# Run main function
main "$@"
