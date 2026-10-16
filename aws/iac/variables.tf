
variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name used for AWS resources"
  type        = string
  default     = "todo-assistant"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "admin_ip_cidr" {
  description = "Your public IP in CIDR format, for example 203.0.113.10/32"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "RDS administrator username"
  type        = string
  default     = "todo_admin"
}

variable "db_password" {
  description = "RDS administrator password"
  type        = string
  sensitive   = true
}
