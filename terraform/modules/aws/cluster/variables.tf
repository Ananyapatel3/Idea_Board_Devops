variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "node_count" {
  type = number
}

variable "node_type" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "public_access_cidrs" {
  type = list(string)
}
