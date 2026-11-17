variable "project_id" {
  type        = string
  description = "GCP Project ID - find this in your GCP console"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "cluster_name" {
  type    = string
  default = "idea-board-gcp"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "node_type" {
  type    = string
  default = "e2-small"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "db_instance_class" {
  type    = string
  default = "db-f1-micro"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "control_plane_authorized_cidrs" {
  type        = list(string)
  description = "Public client CIDR ranges permitted to connect to the GKE API"
  validation {
    condition     = length(var.control_plane_authorized_cidrs) > 0
    error_message = "Provide at least one trusted CIDR for the GKE control plane."
  }
}