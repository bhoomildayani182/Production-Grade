# Terraform Dependency Control Guide

This guide explains how to control task execution order in Terraform using explicit and implicit dependencies.

## 🔄 Dependency Control Methods

### 1. `depends_on` - Explicit Dependencies

Use `depends_on` when you need to force a specific execution order:

```hcl
# Force workers to wait for manager
resource "aws_instance" "swarm_workers" {
  # ... configuration ...
  
  # EXPLICIT: "Create manager FIRST, then workers"
  depends_on = [aws_instance.swarm_manager]
}

# Force load balancer to wait for all instances
resource "aws_lb" "main" {
  # ... configuration ...
  
  # EXPLICIT: "Create ALL instances FIRST, then load balancer"
  depends_on = [
    aws_instance.swarm_manager,
    aws_instance.swarm_workers
  ]
}
```

### 2. Resource References - Implicit Dependencies

Terraform automatically detects dependencies through resource references:

```hcl
# Step 1: Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Step 2: Create Internet Gateway (waits for VPC automatically)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id  # ← IMPLICIT dependency on VPC
}

# Step 3: Create Subnet (waits for VPC automatically)
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id  # ← IMPLICIT dependency on VPC
}

# Step 4: Create Security Group (waits for VPC automatically)
resource "aws_security_group" "manager" {
  vpc_id = aws_vpc.main.id  # ← IMPLICIT dependency on VPC
}

# Step 5: Create EC2 Instance (waits for subnet + security group)
resource "aws_instance" "manager" {
  subnet_id              = aws_subnet.public[0].id           # ← Waits for subnet
  vpc_security_group_ids = [aws_security_group.manager.id]  # ← Waits for security group
  key_name               = aws_key_pair.main.key_name       # ← Waits for key pair
}
```

## 🏗️ Your Project's Dependency Chain

Here's the actual execution order in your Docker Swarm project:

### Phase 1: Foundation (Parallel where possible)
```hcl
# These can run in parallel (no dependencies)
resource "aws_vpc" "main" { }
resource "tls_private_key" "main" { }

# These wait for VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id  # Waits for VPC
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id  # Waits for VPC
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.main.id  # Waits for VPC
}
```

### Phase 2: Networking (Sequential)
```hcl
# NAT Gateway waits for public subnet + IGW
resource "aws_nat_gateway" "main" {
  subnet_id     = aws_subnet.public[count.index].id  # Waits for public subnet
  depends_on    = [aws_internet_gateway.main]        # Waits for IGW
}

# Route tables wait for NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    nat_gateway_id = aws_nat_gateway.main[count.index].id  # Waits for NAT Gateway
  }
}
```

### Phase 3: Security (Waits for VPC)
```hcl
resource "aws_security_group" "swarm_manager" {
  vpc_id = aws_vpc.main.id  # Waits for VPC
}

resource "aws_security_group" "swarm_worker" {
  vpc_id = aws_vpc.main.id  # Waits for VPC
}

resource "aws_key_pair" "main" {
  public_key = tls_private_key.main.public_key_openssh  # Waits for private key
}
```

### Phase 4: Compute (Sequential by Design)
```hcl
# Manager first
resource "aws_instance" "swarm_manager" {
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.swarm_manager.id]
  key_name               = aws_key_pair.main.key_name
  # Implicitly waits for: subnet, security group, key pair
}

# Workers wait for manager (explicit dependency)
resource "aws_instance" "swarm_workers" {
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.swarm_worker.id]
  key_name               = aws_key_pair.main.key_name
  
  # EXPLICIT: Workers must wait for manager
  depends_on = [aws_instance.swarm_manager]
}

# Elastic IP waits for manager + IGW
resource "aws_eip" "swarm_manager" {
  instance   = aws_instance.swarm_manager.id  # Waits for manager
  depends_on = [aws_internet_gateway.main]    # Waits for IGW
}
```

### Phase 5: Load Balancing (Waits for Compute)
```hcl
resource "aws_lb" "main" {
  subnets         = aws_subnet.public[*].id
  security_groups = [aws_security_group.alb.id]
  
  # EXPLICIT: Wait for all instances to be ready
  depends_on = [
    aws_instance.swarm_manager,
    aws_instance.swarm_workers
  ]
}

resource "aws_lb_target_group_attachment" "manager_http" {
  target_id        = aws_instance.swarm_manager.id  # Waits for manager
  target_group_arn = aws_lb_target_group.http.arn   # Waits for target group
}
```

## 🎯 When to Use Each Method

### Use `depends_on` when:
- **Logical dependencies** that Terraform can't detect
- **Timing requirements** (e.g., workers need manager ready)
- **External dependencies** (e.g., waiting for user data scripts)

```hcl
resource "aws_instance" "swarm_workers" {
  # ... config ...
  depends_on = [aws_instance.swarm_manager]  # Manager must be ready first
}
```

### Use Resource References when:
- **Direct resource attributes** are needed
- **Natural dependencies** exist
- **Terraform can auto-detect** the relationship

```hcl
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id  # Natural dependency - subnet needs VPC ID
}
```

## 🔧 Advanced Dependency Patterns

### 1. Multiple Dependencies
```hcl
resource "aws_lb" "main" {
  # ... config ...
  depends_on = [
    aws_instance.swarm_manager,
    aws_instance.swarm_workers,
    aws_nat_gateway.main
  ]
}
```

### 2. Conditional Dependencies
```hcl
resource "aws_route53_record" "main" {
  count = var.enable_route53 ? 1 : 0
  # ... config ...
  depends_on = [aws_lb.main]  # Only if Route53 is enabled
}
```

### 3. Cross-Module Dependencies
```hcl
# In modules, you can pass dependencies
module "application" {
  source = "./modules/app"
  
  # Pass dependency information
  vpc_id    = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id
  
  depends_on = [aws_instance.swarm_manager]
}
```

## 📊 Dependency Visualization

Your project's actual dependency graph:

```
VPC
├── Internet Gateway
├── Subnets (Public/Private)
│   ├── NAT Gateways (depends on IGW)
│   └── Route Tables (depends on NAT)
├── Security Groups
└── Key Pair
    └── EC2 Manager (depends on: subnet, SG, key)
        ├── Elastic IP (depends on: manager, IGW)
        └── EC2 Workers (depends on: manager, subnet, SG, key)
            └── Load Balancer (depends on: all instances, subnets, SG)
                ├── Target Groups
                └── SSL Certificate (if enabled)
                    └── Route53 Records (if enabled)
```

## 🚀 Execution Timeline

With proper dependencies, your deployment follows this timeline:

```
0-1 min:   VPC, IGW, Key Pair (parallel)
1-2 min:   Subnets, Security Groups (parallel)
2-3 min:   NAT Gateways, Route Tables
3-5 min:   Manager Instance + User Data
5-8 min:   Worker Instances (after manager ready)
8-10 min:  Elastic IP, Load Balancer
10-12 min: Target Group Attachments
12-15 min: SSL Certificate, Route53 (if enabled)
```

This ensures your Docker Swarm cluster is built in the correct order with proper dependencies!
