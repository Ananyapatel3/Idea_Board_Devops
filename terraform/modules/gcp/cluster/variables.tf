variable "project_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "node_count" {
  type = number
}

variable "network_id" {
  type = string
}

variable "subnetwork_id" {
  type = string
}

variable "artifact_repository" {
  type = string
}

variable "authorized_cidrs" {
  type = list(string)
}

variable "pod_range_name" {
  type = string
}

variable "service_range_name" {
  type = string
}
