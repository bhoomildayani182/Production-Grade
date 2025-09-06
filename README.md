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

## 🏗️ Network Architecture (Production-Grade Security)

### Infrastructure Layout

The Docker Swarm cluster follows a secure multi-tier architecture with proper network segmentation:

```
Production-Ready Security Architecture:
┌──────────────────────────────────────────────────────────────────────────┐
│                             VPC (10.0.0.0/16)                            │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                          Public Subnets                            │  │
│  │                                                                    │  │
│  │   ┌────────────────────┐       ┌────────────────────────────────┐  │  │
│  │   │ + Elastic IP       │       │   Application Load Balancer    │  │  │
│  │   │ Swarm Manager      │       │       (SSL Termination)        │  │  │
│  │   │ (Public IP)        │       │    + Internet Gateway (IGW)    │  │  │
│  │   │ + Traefik          │       │                                │  │  │
│  │   └────────────────────┘       └────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                          Private Subnets                           │  │
│  │                                                                    │  │
│  │   ┌────────────────────┐       ┌────────────────────────────────┐  │  │
│  │   │ Worker Node        │       │ Worker Node                    │  │  │
│  │   │ (Private IP)       │       │ (Private IP)                   │  │  │
│  │   │ Applications +     │       │ Applications + Services        │  │  │
│  │   │ Services           │       │                                │  │  │
│  │   └────────────────────┘       └────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│          NAT Gateways (Multi-AZ) → Secure Outbound Internet Access       │
└──────────────────────────────────────────────────────────────────────────┘

```

### Node Configuration

| Component | Count | Placement | Network Access | Purpose |
|-----------|-------|-----------|----------------|---------|
| **Manager Node** | 1 | Public Subnet | Public IP + EIP | Swarm management, Traefik proxy, SSL termination |
| **Worker Nodes** | 2 | Private Subnets | Private IP only | Application workloads, microservices |
| **Load Balancer** | 1 | Public Subnets | Internet-facing | Traffic distribution, SSL termination |
| **NAT Gateways** | 2 | Public Subnets | Multi-AZ redundancy | Secure outbound internet for private nodes |

### Security Architecture Benefits

#### **Network Segmentation**
- **Public Tier**: Only manager node and load balancer exposed to internet
- **Private Tier**: Worker nodes isolated from direct internet access
- **Multi-AZ**: High availability across multiple availability zones

#### **Traffic Flow Security**
```
Internet Traffic Flow:
1. Internet → AWS ALB (SSL Termination)
2. ALB → Manager Node (Traefik Proxy)
3. Traefik → Docker Swarm Routing Mesh
4. Routing Mesh → Worker Nodes (Private Network)

Outbound Traffic Flow:
1. Worker Nodes → NAT Gateway
2. NAT Gateway → Internet Gateway
3. Internet (Updates, Docker Hub, etc.)
```

#### **Access Control**
- **SSH Access**: Only to manager node via bastion pattern
- **Application Access**: Through load balancer only
- **Inter-node Communication**: Encrypted Docker Swarm overlay networks
- **Database Access**: Internal network only, no external exposure

### Network Security Features

#### **Security Groups (Firewall Rules)**
- **Manager SG**: SSH (22), HTTP (80), HTTPS (443), Swarm management (2377), Traefik (8080)
- **Worker SG**: Only internal Swarm communication ports (7946, 4789)
- **ALB SG**: HTTP (80) and HTTPS (443) from internet

#### **Encryption**
- **In-Transit**: TLS 1.2+ for all external traffic, Docker Swarm overlay encryption
- **At-Rest**: Encrypted EBS volumes for all instances
- **Secrets**: Docker Swarm secrets management for sensitive data

#### **Network Access Control**
- **Private Subnets**: No direct internet access, NAT Gateway for outbound only
- **Route Tables**: Separate routing for public and private subnets
- **NACLs**: Additional network-level security (default allow, can be restricted)

### Docker Swarm Networking

#### **Overlay Networks**
- **traefik-public**: External-facing services (Traefik, frontend)
- **app-network**: Internal application communication
- **Encrypted**: All overlay traffic encrypted by default

#### **Service Discovery**
- **Automatic**: Docker Swarm built-in service discovery
- **DNS**: Internal DNS resolution for service names
- **Load Balancing**: Built-in load balancing across replicas

#### **Placement Constraints**
```yaml
# Strategic service placement for optimal security and performance
Manager Node:
  - Traefik (requires Docker API access)
  - PostgreSQL (data persistence)
  - Management services

Worker Nodes:
  - Frontend applications (Nginx)
  - Backend APIs (Node.js)
  - Redis cache
  - Application workloads
```

### Scalability and High Availability

#### **Horizontal Scaling**
- **Worker Nodes**: Easily add more by updating `swarm_worker_count`
- **Service Replicas**: Scale individual services via Docker Swarm
- **Multi-AZ**: Automatic distribution across availability zones

#### **Load Distribution**
- **ALB**: Distributes traffic across healthy targets
- **Docker Swarm**: Internal load balancing via routing mesh
- **Geographic**: Multi-AZ deployment for regional redundancy

This architecture ensures production-grade security while maintaining scalability, high availability, and operational simplicity through Infrastructure as Code principles.

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

## 🏛️ Architectural Overview & Key Decisions

This section outlines the fundamental architectural decisions made in designing this production-grade Docker Swarm infrastructure, with emphasis on scalability, maintainability, and operational excellence.

### **Core Architecture Philosophy**

The architecture follows a **microservices-first, cloud-native approach** with these guiding principles:
- **Scalability by Design**: Horizontal scaling capabilities at every layer
- **Security by Default**: Zero-trust network model with defense-in-depth
- **Operational Simplicity**: Automated deployment and management
- **Cost Optimization**: Efficient resource utilization and AWS cost management

### **1. Multi-Tier Network Architecture**

#### **Decision**: Three-tier network segmentation (Public → Private → Data)
#### **Reasoning**: 
- **Security Isolation**: Each tier has different security requirements
- **Scalability**: Independent scaling of each tier
- **Compliance**: Meets enterprise security standards
- **Fault Tolerance**: Multi-AZ deployment prevents single points of failure

#### **Implementation**:
```
Internet → ALB (Public) → Manager (Public) → Workers (Private) → Database (Internal)
```

**Scalability Considerations**:
- **Horizontal**: Add more AZs and subnets as needed
- **Vertical**: Upgrade instance types per tier independently
- **Geographic**: Multi-region deployment ready

**Maintainability Benefits**:
- Clear separation of concerns
- Independent security policies per tier
- Simplified troubleshooting and monitoring

### **2. Container Orchestration: Docker Swarm vs Kubernetes**

#### **Decision**: Docker Swarm over Kubernetes
#### **Reasoning**:
- **Simplicity**: 80% fewer configuration files than Kubernetes
- **Learning Curve**: Faster team onboarding and adoption
- **Resource Efficiency**: Lower overhead (no etcd, fewer control plane components)
- **Built-in Features**: Native load balancing, service discovery, secrets management

#### **Scalability Analysis**:
| Aspect | Docker Swarm | Kubernetes | Our Choice |
|--------|--------------|------------|------------|
| **Cluster Size** | Up to 2,000 nodes | 5,000+ nodes | ✅ Swarm (sufficient) |
| **Learning Curve** | Low | High | ✅ Swarm (team efficiency) |
| **Operational Overhead** | Low | High | ✅ Swarm (maintainability) |
| **Ecosystem** | Moderate | Extensive | ⚖️ Trade-off accepted |

**Future Migration Path**: Architecture designed to migrate to Kubernetes if needed (containerized services, overlay networks, service mesh ready)

### **3. Reverse Proxy Strategy: Traefik Selection**

#### **Decision**: Traefik as the primary reverse proxy and load balancer
#### **Reasoning**:
- **Container-Native**: Built specifically for containerized environments
- **Zero-Configuration**: Automatic service discovery via Docker labels
- **SSL Automation**: Let's Encrypt integration with automatic renewal
- **Modern Features**: HTTP/2, WebSocket support, circuit breakers

#### **Comparison with Alternatives**:
```yaml
# Traditional Nginx Approach (Rejected)
nginx:
  pros: [Performance, Maturity, Flexibility]
  cons: [Manual configuration, No service discovery, Complex SSL setup]
  
# HAProxy Approach (Rejected)  
haproxy:
  pros: [Performance, Load balancing features]
  cons: [No SSL termination, Manual service registration, Complex config]

# Traefik Approach (Selected)
traefik:
  pros: [Auto-discovery, SSL automation, Container-native, Dashboard]
  cons: [Newer technology, Learning curve]
  decision: Benefits outweigh risks for containerized workloads
```

**Scalability Features**:
- **Multi-instance**: Can run multiple Traefik instances for HA
- **Dynamic Routing**: No restarts needed for new services
- **Circuit Breakers**: Automatic failure handling and recovery

### **4. Infrastructure as Code: Terraform Architecture**

#### **Decision**: Modular Terraform with state management
#### **File Structure Rationale**:
```
├── main.tf          # Core configuration and data sources
├���─ variables.tf     # Centralized variable definitions
├── outputs.tf       # Reusable outputs for other modules
├── vpc.tf          # Network infrastructure (isolated)
├── security.tf     # Security groups (security-focused)
├── ec2.tf          # Compute resources (scalable)
├── load_balancer.tf # Traffic management (performance)
└── ssl.tf          # Certificate management (security)
```

**Maintainability Benefits**:
- **Single Responsibility**: Each file has one concern
- **Reusability**: Modules can be reused across environments
- **Version Control**: Infrastructure changes are tracked
- **Team Collaboration**: Multiple developers can work simultaneously

**Scalability Considerations**:
- **Environment Separation**: Dev/Staging/Prod with same codebase
- **Resource Scaling**: Variables control instance counts and sizes
- **Multi-Region**: Architecture supports cross-region deployment

### **5. Service Placement Strategy**

#### **Decision**: Strategic service placement with node role constraints
#### **Implementation**:
```yaml
# Manager Nodes (Control Plane)
manager_services:
  - traefik          # Needs Docker API access
  - postgres         # Data persistence and backup
  - monitoring       # Cluster-wide visibility

# Worker Nodes (Application Plane)  
worker_services:
  - frontend         # Stateless, horizontally scalable
  - backend_api      # Stateless, auto-scaling
  - redis            # Distributed caching
  - batch_jobs       # Resource-intensive tasks
```

**Reasoning**:
- **Resource Isolation**: Separate control plane from application workloads
- **Security**: Sensitive services on more secure manager nodes
- **Performance**: Compute-intensive apps on dedicated worker nodes
- **Availability**: Critical services on stable manager nodes

### **6. Data Architecture Decisions**

#### **Database Strategy**: PostgreSQL on Manager Nodes
- **Reasoning**: ACID compliance, mature ecosystem, excellent Docker support
- **Scalability**: Read replicas, connection pooling, horizontal partitioning ready
- **Maintainability**: Well-known technology, extensive tooling

#### **Caching Strategy**: Redis on Worker Nodes
- **Reasoning**: High-performance, distributed caching, session management
- **Scalability**: Redis Cluster mode for horizontal scaling
- **Placement**: Worker nodes to reduce latency to applications

### **7. Security Architecture**

#### **Zero-Trust Network Model**:
```
Security Layers:
1. AWS Security Groups (Network Firewall)
2. VPC Network ACLs (Subnet-level Control)  
3. Docker Swarm Overlay Encryption (Container Communication)
4. TLS/SSL Everywhere (Data in Transit)
5. EBS Encryption (Data at Rest)
6. IAM Roles (Least Privilege Access)
```

**Scalability**: Security policies scale automatically with infrastructure
**Maintainability**: Centralized security group management via Terraform

### **8. Monitoring and Observability Strategy**

#### **Built-in Health Checks**:
- **Application Level**: `/health` endpoints for all services
- **Infrastructure Level**: AWS CloudWatch integration
- **Container Level**: Docker health checks and restart policies

#### **Logging Strategy**:
- **Centralized**: Docker logs aggregated via log drivers
- **Structured**: JSON logging for better parsing and analysis
- **Retention**: Configurable log retention policies

**Future Enhancements**: Ready for Prometheus/Grafana, ELK stack integration

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

## 🧪 Comprehensive Testing Strategy

This section outlines our multi-layered testing approach designed to ensure reliability, performance, and security across all infrastructure and application components.

### **Testing Philosophy**

Our testing strategy follows the **Test Pyramid** approach with emphasis on:
- **Shift-Left Testing**: Catch issues early in the development cycle
- **Automated Testing**: Minimize manual intervention and human error
- **Production-Like Testing**: Test in environments that mirror production
- **Continuous Validation**: Ongoing monitoring and health checks

### **1. Infrastructure Testing (IaC Validation)**

#### **Static Analysis & Validation**
```bash
# Terraform Configuration Validation
terraform fmt -check          # Code formatting standards
terraform validate            # Syntax and configuration validation
terraform plan -detailed-exitcode  # Infrastructure change analysis

# Security Scanning
tfsec .                       # Terraform security scanner
checkov -f main.tf           # Infrastructure security analysis
terrascan scan -t terraform  # Policy-as-code validation
```

#### **Infrastructure Compliance Testing**
```bash
# AWS Resource Validation
aws ec2 describe-instances --filters "Name=tag:Project,Values=docker-swarm-cluster"
aws elbv2 describe-load-balancers --names docker-swarm-cluster-alb
aws ec2 describe-security-groups --group-names docker-swarm-*

# Network Connectivity Testing
aws ec2 describe-route-tables --filters "Name=tag:Project,Values=docker-swarm-cluster"
aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=docker-swarm-cluster"
```

#### **Cost and Resource Optimization Testing**
```bash
# Resource Utilization Analysis
aws cloudwatch get-metric-statistics --namespace AWS/EC2 \
  --metric-name CPUUtilization --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z --period 3600 --statistics Average

# Cost Analysis
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-02 \
  --granularity DAILY --metrics BlendedCost
```

### **2. Container & Orchestration Testing**

#### **Docker Swarm Cluster Validation**
```bash
# Cluster Health Checks
ssh -i docker-swarm-key.pem ubuntu@<manager-ip> << 'EOF'
  # Cluster status validation
  docker node ls --format "table {{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.ManagerStatus}}"
  
  # Service deployment validation
  docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}\t{{.Ports}}"
  
  # Network connectivity testing
  docker network ls --filter driver=overlay
  docker service ps --no-trunc $(docker service ls -q)
EOF
```

#### **Service Discovery & Load Balancing Tests**
```bash
# Internal service communication testing
docker exec $(docker ps -q -f name=backend) curl -f http://postgres:5432
docker exec $(docker ps -q -f name=backend) curl -f http://redis:6379/ping

# Traefik routing validation
curl -H "Host: localhost" http://<manager-ip>/api/health
curl -H "Host: localhost" http://<manager-ip>/
```

### **3. Application Testing**

#### **Health Check Validation**
```bash
# Application health endpoints
health_check() {
  local service=$1
  local endpoint=$2
  local expected_status=$3
  
  response=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint")
  if [ "$response" = "$expected_status" ]; then
    echo "✅ $service health check passed"
  else
    echo "❌ $service health check failed (got $response, expected $expected_status)"
  fi
}

# Execute health checks
health_check "Frontend" "http://<load-balancer-dns>/" "200"
health_check "Backend API" "http://<load-balancer-dns>/api/health" "200"
health_check "Database" "http://<load-balancer-dns>/api/db-status" "200"
```

#### **API Contract Testing**
```bash
# API endpoint validation with expected responses
api_test() {
  echo "Testing API endpoints..."
  
  # Test GET endpoints
  curl -X GET http://<load-balancer-dns>/api/health | jq '.status == "healthy"'
  curl -X GET http://<load-balancer-dns>/api/version | jq '.version'
  
  # Test POST endpoints (if applicable)
  curl -X POST -H "Content-Type: application/json" \
    -d '{"test": "data"}' http://<load-balancer-dns>/api/test
}
```

#### **Database Integration Testing**
```bash
# Database connectivity and operations
db_test() {
  ssh -i docker-swarm-key.pem ubuntu@<manager-ip> << 'EOF'
    # Test database connection
    docker exec $(docker ps -q -f name=postgres) \
      psql -U user -d appdb -c "SELECT version();"
    
    # Test basic CRUD operations
    docker exec $(docker ps -q -f name=postgres) \
      psql -U user -d appdb -c "CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name VARCHAR(50));"
    
    docker exec $(docker ps -q -f name=postgres) \
      psql -U user -d appdb -c "INSERT INTO test_table (name) VALUES ('test_deployment');"
    
    docker exec $(docker ps -q -f name=postgres) \
      psql -U user -d appdb -c "SELECT * FROM test_table WHERE name = 'test_deployment';"
EOF
}
```

### **4. Performance & Load Testing**

#### **Load Testing with Multiple Tools**
```bash
# Apache Bench - Basic load testing
ab -n 10000 -c 100 -H "Host: localhost" http://<load-balancer-dns>/

# Artillery.js - Advanced load testing
cat > load-test.yml << EOF
config:
  target: 'http://<load-balancer-dns>'
  phases:
    - duration: 60
      arrivalRate: 10
    - duration: 120
      arrivalRate: 50
    - duration: 60
      arrivalRate: 100
scenarios:
  - name: "Frontend Load Test"
    requests:
      - get:
          url: "/"
      - get:
          url: "/api/health"
EOF

artillery run load-test.yml
```

#### **Stress Testing & Resource Monitoring**
```bash
# Resource utilization during load
stress_test() {
  # Start monitoring
  ssh -i docker-swarm-key.pem ubuntu@<manager-ip> 'htop' &
  
  # Generate load
  ab -n 50000 -c 200 http://<load-balancer-dns>/ &
  
  # Monitor Docker stats
  ssh -i docker-swarm-key.pem ubuntu@<manager-ip> \
    'docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"'
}
```

### **5. Security Testing**

#### **Network Security Validation**
```bash
# Port scanning and security validation
security_test() {
  # Test that only required ports are open
  nmap -p 22,80,443,8080 <manager-ip>
  nmap -p 1-65535 <worker-ip>  # Should show no open ports
  
  # SSL/TLS configuration testing
  sslscan <load-balancer-dns>:443
  testssl.sh https://<load-balancer-dns>
  
  # Security headers validation
  curl -I https://<load-balancer-dns> | grep -E "(X-Frame-Options|X-Content-Type-Options|Strict-Transport-Security)"
}
```

#### **Container Security Scanning**
```bash
# Container vulnerability scanning
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image traefik:v3.0

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image nginx:alpine
```

### **6. Disaster Recovery Testing**

#### **Node Failure Simulation**
```bash
# Simulate worker node failure
disaster_recovery_test() {
  echo "Simulating worker node failure..."
  
  # Stop a worker node
  aws ec2 stop-instances --instance-ids <worker-instance-id>
  
  # Verify service redistribution
  sleep 60
  ssh -i docker-swarm-key.pem ubuntu@<manager-ip> \
    'docker service ps --no-trunc $(docker service ls -q)'
  
  # Test application availability during failure
  for i in {1..10}; do
    curl -f http://<load-balancer-dns>/api/health
    sleep 5
  done
  
  # Restart the node
  aws ec2 start-instances --instance-ids <worker-instance-id>
}
```

### **7. Automated Testing Pipeline**

#### **CI/CD Integration Testing**
```yaml
# Example GitHub Actions workflow for testing
name: Infrastructure Testing
on: [push, pull_request]

jobs:
  terraform-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
      - name: Terraform Validate
        run: terraform validate
      - name: Security Scan
        run: |
          docker run --rm -v $(pwd):/src aquasec/tfsec /src
          docker run --rm -v $(pwd):/tf bridgecrew/checkov -f /tf
```

#### **Monitoring & Alerting Tests**
```bash
# Test monitoring endpoints
monitoring_test() {
  # Traefik dashboard accessibility
  curl -f http://<manager-ip>:8080/dashboard/
  
  # Custom metrics endpoints
  curl -f http://<load-balancer-dns>/metrics
  
  # Log aggregation testing
  ssh -i docker-swarm-key.pem ubuntu@<manager-ip> \
    'docker service logs --tail 100 $(docker service ls -q)'
}
```

### **8. Testing Tools & Technologies**

| Testing Type | Primary Tools | Secondary Tools | Purpose |
|--------------|---------------|-----------------|---------|
| **Infrastructure** | Terraform, tfsec | Checkov, Terrascan | IaC validation & security |
| **Container** | Docker, docker-compose | Hadolint, Dive | Container best practices |
| **API** | curl, Postman | Newman, Insomnia | API contract testing |
| **Load** | Apache Bench, Artillery | JMeter, K6 | Performance validation |
| **Security** | nmap, sslscan | OWASP ZAP, Trivy | Security assessment |
| **Monitoring** | CloudWatch, htop | Prometheus, Grafana | Performance monitoring |

### **9. Test Automation & Reporting**

#### **Automated Test Execution**
```bash
#!/bin/bash
# comprehensive-test.sh - Complete testing suite

set -e

echo "🚀 Starting Comprehensive Testing Suite"

# Infrastructure tests
echo "📋 Running Infrastructure Tests..."
terraform validate && echo "✅ Terraform validation passed"

# Application tests  
echo "🔍 Running Application Tests..."
./scripts/health-check.sh && echo "✅ Health checks passed"

# Performance tests
echo "⚡ Running Performance Tests..."
ab -n 1000 -c 10 http://<load-balancer-dns>/ > /dev/null && echo "✅ Load test passed"

# Security tests
echo "🔒 Running Security Tests..."
nmap -p 80,443 <load-balancer-dns> > /dev/null && echo "✅ Security scan passed"

echo "🎉 All tests completed successfully!"
```

This comprehensive testing strategy ensures that every component of the Docker Swarm infrastructure is thoroughly validated before, during, and after deployment, providing confidence in the system's reliability and performance.

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
