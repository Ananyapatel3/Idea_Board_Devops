resource "google_service_account" "nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "Idea Board GKE node service account"
  project      = var.project_id
}

resource "google_artifact_registry_repository_iam_member" "artifact_reader" {
  project    = var.project_id
  location   = var.region
  repository = var.artifact_repository
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_project_iam_member" "node_service_account" {
  project = var.project_id
  role    = "roles/container.nodeServiceAccount"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  name                     = var.cluster_name
  location                 = var.region
  network                  = var.network_id
  subnetwork               = var.subnetwork_id
  remove_default_node_pool = true
  initial_node_count       = 1
  project                  = var.project_id
  deletion_protection      = false

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_range_name
    services_secondary_range_name = var.service_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value
        display_name = "deployment-client-${cidr_blocks.key}"
      }
    }
  }

  node_config {
    machine_type    = var.machine_type
    disk_type       = "pd-standard"
    disk_size_gb    = 30
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_container_node_pool" "this" {
  name       = "${var.cluster_name}-nodes"
  cluster    = google_container_cluster.this.name
  location   = var.region
  node_count = var.node_count
  project    = var.project_id

  node_config {
    machine_type    = var.machine_type
    disk_type       = "pd-standard"
    disk_size_gb    = 30
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  depends_on = [
    google_artifact_registry_repository_iam_member.artifact_reader,
    google_project_iam_member.node_service_account,
  ]
}
