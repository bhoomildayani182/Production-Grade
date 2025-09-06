# User Data Scripts for Docker Installation and Swarm Setup

# User data script for Docker Swarm Manager
locals {
  manager_user_data = base64encode(templatefile("${path.module}/scripts/manager_setup.sh", {
    project_name = var.project_name
    environment  = var.environment
  }))

  worker_user_data = base64encode(templatefile("${path.module}/scripts/worker_setup.sh", {
    project_name    = var.project_name
    environment     = var.environment
    manager_ip      = aws_instance.swarm_manager.private_ip
  }))
}
