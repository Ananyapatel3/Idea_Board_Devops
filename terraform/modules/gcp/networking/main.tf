resource "google_compute_network" "this" {
  name                    = "idea-board-vpc-${var.environment}"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "this" {
  count         = 2
  name          = "idea-board-subnet-${count.index}-${var.environment}"
  ip_cidr_range = cidrsubnet(var.cidr_block, 8, count.index)
  region        = var.region
  network       = google_compute_network.this.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "pods-${var.environment}-${count.index}"
    ip_cidr_range = cidrsubnet("10.16.0.0/16", 4, count.index)
  }

  secondary_ip_range {
    range_name    = "services-${var.environment}-${count.index}"
    ip_cidr_range = cidrsubnet("10.32.0.0/16", 8, count.index)
  }
}

resource "google_compute_router" "this" {
  name    = "idea-board-router-${var.environment}"
  region  = var.region
  network = google_compute_network.this.id
  project = var.project_id
}

resource "google_compute_router_nat" "this" {
  name                               = "idea-board-nat-${var.environment}"
  router                             = google_compute_router.this.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  dynamic "subnetwork" {
    for_each = google_compute_subnetwork.this
    content {
      name                    = subnetwork.value.id
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }
}
