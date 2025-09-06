# Variable definitions for Docker Swarm infrastructure

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "docker-swarm-cluster"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for Docker Swarm nodes"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of the AWS key pair for EC2 instances"
  type        = string
  default     = "docker-swarm-key"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the infrastructure"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}

variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}

variable "enable_route53" {
  description = "Enable Route53 DNS configuration"
  type        = bool
  default     = false
}

variable "enable_ssl" {
  description = "Enable SSL/TLS with Let's Encrypt"
  type        = bool
  default     = true
}

variable "swarm_manager_count" {
  description = "Number of Docker Swarm manager nodes"
  type        = number
  default     = 1
}

variable "swarm_worker_count" {
  description = "Number of Docker Swarm worker nodes"
  type        = number
  default     = 2
}
