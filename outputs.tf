# Output values for the Docker Swarm infrastructure

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "swarm_manager_public_ip" {
  description = "Public IP address of the Docker Swarm manager"
  value       = aws_instance.swarm_manager.public_ip
}

output "swarm_manager_private_ip" {
  description = "Private IP address of the Docker Swarm manager"
  value       = aws_instance.swarm_manager.private_ip
}

output "swarm_worker_public_ips" {
  description = "Public IP addresses of Docker Swarm workers"
  value       = aws_instance.swarm_workers[*].public_ip
}

output "swarm_worker_private_ips" {
  description = "Private IP addresses of Docker Swarm workers"
  value       = aws_instance.swarm_workers[*].private_ip
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "ssh_command_manager" {
  description = "SSH command to connect to the manager node"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.swarm_manager.public_ip}"
}

output "ssh_commands_workers" {
  description = "SSH commands to connect to worker nodes"
  value       = [for i, worker in aws_instance.swarm_workers : "ssh -i ${var.key_name}.pem ubuntu@${worker.public_ip}"]
}

output "application_url" {
  description = "URL to access the deployed application"
  value       = var.enable_route53 && var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}
