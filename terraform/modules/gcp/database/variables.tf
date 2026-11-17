variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.db_password) >= 16
    error_message = "Use a database password containing at least 16 characters."
  }
}

variable "region" {
  type = string
}

variable "tier" {
  type = string
}

variable "network_id" {
  type = string
}

variable "private_service_cidr" {
  type    = string
  default = "10.1.0.0/16"
}
