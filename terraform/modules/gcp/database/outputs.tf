output "connection_string" {
  value     = "postgresql+psycopg2://${urlencode(var.db_username)}:${urlencode(var.db_password)}@${google_sql_database_instance.this.private_ip_address}:5432/${var.db_name}"
  sensitive = true
}
