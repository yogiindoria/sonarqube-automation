variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair name"
  type        = string
  default     = "VM2"
}

variable "allowed_ssh_cidr" {
  description = "Your public IP in CIDR format, for example 203.0.113.10/32"
  type        = string
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "sonarqube_instance_type" {
  type    = string
  default = "t3.small"
}