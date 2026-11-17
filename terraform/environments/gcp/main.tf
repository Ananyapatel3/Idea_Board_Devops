terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "idea-board-tfstate-gcp"
    prefix = "gcp"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "required" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "idea-board"
  description   = "Docker images for the Idea Board application"
  format        = "DOCKER"
  project       = var.project_id
  depends_on    = [google_project_service.required]
}

module "networking" {
  source      = "../../modules/gcp/networking"
  project_id  = var.project_id
  environment = var.environment
  region      = var.region
  cidr_block  = var.vpc_cidr
  depends_on  = [google_project_service.required]
}

module "cluster" {
  source              = "../../modules/gcp/cluster"
  project_id          = var.project_id
  cluster_name        = var.cluster_name
  region              = var.region
  machine_type        = var.node_type
  node_count          = var.node_count
  network_id          = module.networking.network_id
  subnetwork_id       = module.networking.subnetwork_ids[0]
  artifact_repository = google_artifact_registry_repository.images.repository_id
  authorized_cidrs    = var.control_plane_authorized_cidrs
  pod_range_name      = "pods-${var.environment}-0"
  service_range_name  = "services-${var.environment}-0"
  depends_on          = [google_project_service.required]
}

module "database" {
  source      = "../../modules/gcp/database"
  project_id  = var.project_id
  environment = var.environment
  db_name     = "ideas"
  db_username = "ideas_user"
  db_password = var.db_password
  region      = var.region
  tier        = var.db_instance_class
  network_id  = module.networking.network_id
  depends_on  = [google_project_service.required]
}

output "cluster_name" {
  value = module.cluster.cluster_name
}

output "region" {
  value = var.region
}

output "db_connection_string" {
  value     = module.database.connection_string
  sensitive = true
}

output "image_repository" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}
