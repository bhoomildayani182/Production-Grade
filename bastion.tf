# Optional: Dedicated Bastion Host for Private Subnet Access
# Uncomment and customize if you want a separate bastion instead of using manager

# resource "aws_instance" "bastion" {
#   ami                    = data.aws_ami.ubuntu.id
#   instance_type          = "t3.micro"  # Smaller instance for bastion
#   key_name               = aws_key_pair.main.key_name
#   vpc_security_group_ids = [aws_security_group.bastion.id]
#   subnet_id              = aws_subnet.public[0].id
#   
#   user_data = <<-EOF
#     #!/bin/bash
#     apt-get update -y
#     apt-get install -y htop vim curl
#   EOF
#
#   tags = {
#     Name = "${var.project_name}-bastion"
#     Role = "Bastion"
#   }
# }

# resource "aws_security_group" "bastion" {
#   name_prefix = "${var.project_name}-bastion-"
#   vpc_id      = aws_vpc.main.id
#
#   # SSH access from allowed IPs
#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = var.allowed_cidr_blocks
#   }
#
#   # All outbound traffic
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   tags = {
#     Name = "${var.project_name}-bastion-sg"
#   }
# }

# resource "aws_eip" "bastion" {
#   instance = aws_instance.bastion.id
#   domain   = "vpc"
#
#   tags = {
#     Name = "${var.project_name}-bastion-eip"
#   }
# }
