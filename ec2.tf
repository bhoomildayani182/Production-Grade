# EC2 Instances for Docker Swarm Cluster

# Docker Swarm Manager Instance
resource "aws_instance" "swarm_manager" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.swarm_manager.id]
  subnet_id              = aws_subnet.public[0].id
  
  user_data = local.manager_user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  # Additional EBS volume for Docker data
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 50
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-swarm-manager"
    Role = "SwarmManager"
    Type = "Manager"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Docker Swarm Worker Instances
resource "aws_instance" "swarm_workers" {
  count = var.swarm_worker_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.swarm_worker.id]
  subnet_id              = aws_subnet.private[count.index % length(aws_subnet.private)].id
  
  user_data = local.worker_user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  # Additional EBS volume for Docker data
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 50
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-swarm-worker-${count.index + 1}"
    Role = "SwarmWorker"
    Type = "Worker"
  }

  depends_on = [aws_instance.swarm_manager]

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for Swarm Manager (optional but recommended for production)
resource "aws_eip" "swarm_manager" {
  instance = aws_instance.swarm_manager.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-manager-eip"
  }

  depends_on = [aws_internet_gateway.main]
}
