# Application Load Balancer for Docker Swarm Cluster

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  # Explicit dependency: Wait for EC2 instances to be ready
  depends_on = [
    aws_instance.swarm_manager,
    aws_instance.swarm_workers
  ]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for HTTP traffic
resource "aws_lb_target_group" "http" {
  name     = "${var.project_name}-http-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-http-tg"
  }
}

# Target Group for HTTPS traffic
resource "aws_lb_target_group" "https" {
  name     = "${var.project_name}-https-tg"
  port     = 443
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-https-tg"
  }
}

# Attach Swarm Manager to target groups
resource "aws_lb_target_group_attachment" "manager_http" {
  target_group_arn = aws_lb_target_group.http.arn
  target_id        = aws_instance.swarm_manager.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "manager_https" {
  target_group_arn = aws_lb_target_group.https.arn
  target_id        = aws_instance.swarm_manager.id
  port             = 443
}

# Note: Workers are in private subnets and will be reached via Docker Swarm routing mesh
# The manager node will route traffic to workers automatically through the overlay network
# This is more secure and follows Docker Swarm best practices

# HTTP Listener (redirects to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count = var.enable_ssl ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.main[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }

  depends_on = [aws_acm_certificate_validation.main]
}

# HTTP Listener for non-SSL setup
resource "aws_lb_listener" "http_direct" {
  count = var.enable_ssl ? 0 : 1

  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}
