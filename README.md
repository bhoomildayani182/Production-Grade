# Production-Grade Docker Swarm Cluster on AWS

A comprehensive Infrastructure as Code (IaC) solution for deploying a secure, scalable Docker Swarm cluster on AWS with a sample microservices application.

## 🏗️ Architecture Overview

This project creates a production-ready Docker Swarm cluster with the following components:

### Infrastructure Components
- **VPC**: Custom VPC with public/private subnets across multiple AZs
- **EC2 Instances**: 1 Manager node + 2 Worker nodes (configurable)
- **Load Balancer**: AWS Application Load Balancer with SSL termination
- **Security**: Security groups with least-privilege access
- **DNS**: Optional Route53 integration with custom domain
- **SSL/TLS**: Let's Encrypt certificates via Traefik

### Application Stack
- **Reverse Proxy**: Traefik with automatic SSL and service discovery
- **Frontend**: Nginx serving a responsive dashboard
- **Backend**: Node.js REST API with health checks
- **Database**: PostgreSQL for persistent data
- **Cache**: Redis for session management and caching
- **Monitoring**: Built-in health checks and logging

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- SSH client
- Domain name (optional, for SSL)

### 1. Clone and Configure
```bash
git clone <repository-url>
cd docker-swarm-infrastructure
cp terraform.tfvars.example terraform.tfvars
```

### 2. Configure Variables
Edit `terraform.tfvars`:
```hcl
aws_region = "us-west-2"
project_name = "my-swarm-cluster"
instance_type = "t3.medium"
domain_name = "example.com"  # Optional
enable_route53 = true        # If using custom domain
```

### 3. Deploy Infrastructure
```bash
chmod +x deploy.sh destroy.sh
./deploy.sh
```

### 4. Access Your Application
- **Application**: `https://your-domain.com` or `http://load-balancer-dns`
- **Traefik Dashboard**: `http://manager-ip:8080`
- **SSH to Manager**: `ssh -i docker-swarm-key.pem ubuntu@manager-ip`

## 📁 Project Structure

```
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Variable definitions
├── outputs.tf             # Output values
├── vpc.tf                 # VPC and networking
├── security.tf            # Security groups
├── ec2.tf                 # EC2 instances
├── load_balancer.tf       # Application Load Balancer
├── ssl.tf                 # SSL/TLS certificates
├── route53.tf             # DNS configuration
├── key_pair.tf            # SSH key management
├── user_data.tf           # Instance initialization
├── scripts/
│   ├── manager_setup.sh   # Manager node setup
│   └── worker_setup.sh    # Worker node setup
├── app/
│   ├── docker-compose.yml # Application stack definition
│   ├── frontend/          # Nginx frontend
│   └── backend/           # Node.js API
├── deploy.sh              # Deployment script
├── destroy.sh             # Cleanup script
└── README.md              # This file
```

## 🏛️ Architectural Decisions

### 1. **Multi-AZ Deployment**
- **Decision**: Deploy across multiple Availability Zones
- **Reasoning**: Ensures high availability and fault tolerance
- **Implementation**: Public/private subnets in 2+ AZs with NAT gateways

### 2. **Security-First Approach**
- **Decision**: Implement defense-in-depth security
- **Reasoning**: Production workloads require robust security
- **Implementation**: 
  - Security groups with minimal required ports
  - Private subnets for databases
  - Encrypted EBS volumes
  - SSL/TLS everywhere

### 3. **Traefik as Reverse Proxy**
- **Decision**: Use Traefik instead of traditional load balancers
- **Reasoning**: 
  - Automatic service discovery
  - Built-in Let's Encrypt integration
  - Docker Swarm native support
- **Implementation**: Deployed on manager nodes with overlay networks

### 4. **Infrastructure as Code**
- **Decision**: Use Terraform for all infrastructure
- **Reasoning**: 
  - Version control and reproducibility
  - State management
  - Team collaboration
- **Implementation**: Modular Terraform with clear separation of concerns

### 5. **Placement Constraints**
- **Decision**: Strategic service placement across nodes
- **Reasoning**: Optimize resource utilization and availability
- **Implementation**:
  - Traefik on manager nodes (access to Docker API)
  - Applications on worker nodes (resource isolation)
  - Database on manager (data persistence)

## 🔧 Technology Choices

### Infrastructure
- **AWS**: Mature cloud platform with comprehensive services
- **Terraform**: Industry-standard IaC tool with excellent AWS support
- **Ubuntu 22.04 LTS**: Stable, secure, and well-supported

### Container Orchestration
- **Docker Swarm**: Simpler than Kubernetes, built into Docker
- **Overlay Networks**: Secure multi-host networking
- **Docker Secrets**: Secure credential management

### Application Stack
- **Traefik**: Modern reverse proxy with automatic SSL
- **Nginx**: High-performance web server
- **Node.js**: Fast, scalable backend runtime
- **PostgreSQL**: Reliable, feature-rich database
- **Redis**: High-performance caching layer

## 📊 Scalability Considerations

### Horizontal Scaling
- **Worker Nodes**: Easily add more workers by increasing `swarm_worker_count`
- **Service Replicas**: Scale individual services via Docker Swarm
- **Load Balancing**: AWS ALB distributes traffic across all nodes

### Vertical Scaling
- **Instance Types**: Upgrade to larger instances as needed
- **Storage**: EBS volumes can be resized without downtime
- **Database**: PostgreSQL supports read replicas and connection pooling

### Auto Scaling (Future Enhancement)
- **ASG Integration**: Could integrate with Auto Scaling Groups
- **Spot Instances**: Cost optimization with mixed instance types
- **CloudWatch Metrics**: Custom metrics for scaling decisions

## 🧪 Testing Strategy

### Infrastructure Testing
```bash
# Validate Terraform configuration
terraform validate

# Plan deployment (dry run)
terraform plan

# Check AWS resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=docker-swarm-cluster"
```

### Application Testing
```bash
# SSH to manager and check cluster
ssh -i docker-swarm-key.pem ubuntu@<manager-ip>
docker node ls
docker service ls

# Test API endpoints
curl http://<load-balancer-dns>/api/health
curl http://<load-balancer-dns>/api/test
```

### Load Testing
```bash
# Using Apache Bench
ab -n 1000 -c 10 http://<load-balancer-dns>/

# Using curl for health checks
for i in {1..10}; do curl -s http://<load-balancer-dns>/health; done
```

## 🔒 Security Measures

### Network Security
- **VPC Isolation**: Custom VPC with controlled routing
- **Security Groups**: Least-privilege firewall rules
- **Private Subnets**: Database and internal services isolated
- **NAT Gateways**: Secure outbound internet access

### Application Security
- **SSL/TLS**: End-to-end encryption with Let's Encrypt
- **Security Headers**: Nginx configured with security headers
- **Rate Limiting**: API rate limiting to prevent abuse
- **Health Checks**: Continuous monitoring of service health

### Access Control
- **SSH Keys**: Key-based authentication only
- **IAM Roles**: Minimal required AWS permissions
- **Docker Secrets**: Secure credential management
- **Non-root Containers**: Applications run as non-privileged users

## 📈 Monitoring and Logging

### Built-in Monitoring
- **Health Checks**: Application and infrastructure health endpoints
- **Docker Logs**: Centralized logging via Docker daemon
- **CloudWatch**: AWS native monitoring (optional)

### Custom Metrics
- **Application Metrics**: `/metrics` endpoint with performance data
- **Cluster Status**: Docker Swarm node and service status
- **Resource Usage**: CPU, memory, and disk utilization

## 🚀 Deployment Process

### Automated Deployment
1. **Infrastructure Provisioning**: Terraform creates AWS resources
2. **Node Configuration**: User data scripts install Docker and join Swarm
3. **Application Deployment**: Docker Compose stack deployment
4. **Health Verification**: Automated health checks

### Manual Steps (if needed)
```bash
# Connect to manager node
ssh -i docker-swarm-key.pem ubuntu@<manager-ip>

# Deploy application stack
cd /opt/docker-swarm/app
docker stack deploy -c docker-compose.yml swarm-app

# Check deployment status
docker service ls
docker stack ps swarm-app
```

## 🔄 Maintenance

### Regular Tasks
- **Security Updates**: Regular OS and Docker updates
- **Certificate Renewal**: Let's Encrypt handles automatic renewal
- **Backup**: Database backup strategy (implement as needed)
- **Monitoring**: Review logs and metrics regularly

### Scaling Operations
```bash
# Scale a service
docker service scale swarm-app_backend=5

# Add worker nodes
# Update swarm_worker_count in terraform.tfvars and re-apply
```

## 🧹 Cleanup

To destroy all resources:
```bash
./destroy.sh
```

This will:
1. Remove Docker services and stacks
2. Destroy AWS infrastructure
3. Clean up local files (optional)

## 📝 Customization

### Environment Variables
Modify `terraform.tfvars` for different environments:
- Development: Smaller instances, single AZ
- Staging: Production-like but smaller scale
- Production: Multi-AZ, larger instances, monitoring

### Application Changes
- **Frontend**: Modify `app/frontend/html/index.html`
- **Backend**: Update `app/backend/server.js`
- **Services**: Add new services to `docker-compose.yml`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

**Issue**: Terraform apply fails with permission errors
**Solution**: Ensure AWS credentials have sufficient permissions for EC2, VPC, and IAM operations

**Issue**: Docker Swarm nodes fail to join
**Solution**: Check security group rules allow port 2377 between nodes

**Issue**: Application not accessible
**Solution**: Verify load balancer target group health and security group rules

**Issue**: SSL certificate not working
**Solution**: Ensure domain name is correctly configured and DNS is propagated

### Getting Help
- Check AWS CloudWatch logs for detailed error messages
- SSH to manager node and check Docker logs: `docker service logs <service-name>`
- Verify security group rules and network connectivity
- Ensure all required ports are open between nodes

## 📞 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review AWS CloudWatch logs
3. Check Docker service logs on the manager node
4. Open an issue in the repository with detailed error information

---

**Note**: This is a demonstration project for DevOps technical assessment. For production use, consider additional security hardening, monitoring solutions, and backup strategies based on your specific requirements.
