# SSH Key Pair for EC2 instances

# Generate a private key
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair
resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = "${var.project_name}-key-pair"
  }
}

# Save private key to local file
resource "local_file" "private_key" {
  content  = tls_private_key.main.private_key_pem
  filename = "${path.module}/${var.key_name}.pem"
  
  provisioner "local-exec" {
    command = "chmod 600 ${path.module}/${var.key_name}.pem"
  }
}
