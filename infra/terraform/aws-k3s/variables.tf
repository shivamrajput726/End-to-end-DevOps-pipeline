variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "name_prefix" {
  type        = string
  description = "Resource name prefix"
  default     = "devops-demo"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.small"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key (contents of .pub file)"
}

variable "ssh_cidr" {
  type        = string
  description = "CIDR allowed to SSH and access k8s API (e.g., your_ip/32)"
  default     = "0.0.0.0/0"
}

variable "k3s_version" {
  type        = string
  description = "k3s version (as accepted by get.k3s.io)"
  default     = "v1.30.5+k3s1"
}

