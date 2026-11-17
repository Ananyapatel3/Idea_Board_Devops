resource "google_compute_global_address" "private_services" {
  name          = "${var.environment}-private-services"
  address       = split("/", var.private_service_cidr)[0]
  prefix_length = tonumber(split("/", var.private_service_cidr)[1])
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = var.network_id
  project       = var.project_id
}

resource "google_service_networking_connection" "private_services" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

resource "google_sql_database_instance" "this" {
  name                = "${var.environment}-ideas-db"
  database_version    = "POSTGRES_15"
  region              = var.region
  project             = var.project_id
  deletion_protection = true

  settings {
    tier = var.tier

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }
  }

  depends_on = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "this" {
  name     = var.db_name
  instance = google_sql_database_instance.this.name
  project  = var.project_id
}

resource "google_sql_user" "this" {
  name     = var.db_username
  instance = google_sql_database_instance.this.name
  password = var.db_password
  project  = var.project_id
}
