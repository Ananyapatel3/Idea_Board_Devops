variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "cluster_name" {
  type    = string
  default = "idea-board-aws"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "node_type" {
  type    = string
  default = "t3.small"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "control_plane_authorized_cidrs" {
  type        = list(string)
  description = "Public client CIDR ranges permitted to connect to the EKS API"
  validation {
    condition     = length(var.control_plane_authorized_cidrs) > 0
    error_message = "Provide at least one trusted CIDR for the EKS public API endpoint."
  }
}