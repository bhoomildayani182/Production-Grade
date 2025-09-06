# Security Groups for Docker Swarm Cluster

# Security group for Docker Swarm Manager
resource "aws_security_group" "swarm_manager" {
  name_prefix = "${var.project_name}-manager-"
  vpc_id      = aws_vpc.main.id

  description = "Security group for Docker Swarm manager node"

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Docker Swarm management port
  ingress {
    description     = "Docker Swarm Management"
    from_port       = 2377
    to_port         = 2377
    protocol        = "tcp"
    security_groups = [aws_security_group.swarm_worker.id]
  }

  # Docker daemon API (if needed)
  ingress {
    description     = "Docker Daemon API"
    from_port       = 2376
    to_port         = 2376
    protocol        = "tcp"
    security_groups = [aws_security_group.swarm_worker.id]
  }

  # Container network discovery
  ingress {
    description     = "Container Network Discovery"
    from_port       = 7946
    to_port         = 7946
    protocol        = "tcp"
    security_groups = [aws_security_group.swarm_worker.id]
  }

  ingress {
    description     = "Container Network Discovery UDP"
    from_port       = 7946
    to_port         = 7946
    protocol        = "udp"
    security_groups = [aws_security_group.swarm_worker.id]
  }

  # Overlay network traffic
  ingress {
    description     = "Overlay Network Traffic"
    from_port       = 4789
    to_port         = 4789
    protocol        = "udp"
    security_groups = [aws_security_group.swarm_worker.id]
  }

  # HTTP and HTTPS for applications
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Traefik dashboard (restrict in production)
  ingress {
    description = "Traefik Dashboard"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-manager-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security group for Docker Swarm Workers
resource "aws_security_group" "swarm_worker" {
  name_prefix = "${var.project_name}-worker-"
  vpc_id      = aws_vpc.main.id

  description = "Security group for Docker Swarm worker nodes"

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Container network discovery
  ingress {
    description     = "Container Network Discovery"
    from_port       = 7946
    to_port         = 7946
    protocol        = "tcp"
    security_groups = [aws_security_group.swarm_manager.id]
    self            = true
  }

  ingress {
    description     = "Container Network Discovery UDP"
    from_port       = 7946
    to_port         = 7946
    protocol        = "udp"
    security_groups = [aws_security_group.swarm_manager.id]
    self            = true
  }

  # Overlay network traffic
  ingress {
    description     = "Overlay Network Traffic"
    from_port       = 4789
    to_port         = 4789
    protocol        = "udp"
    security_groups = [aws_security_group.swarm_manager.id]
    self            = true
  }

  # HTTP and HTTPS for applications
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-worker-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = aws_vpc.main.id

  description = "Security group for Application Load Balancer"

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
