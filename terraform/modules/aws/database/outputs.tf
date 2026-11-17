output "connection_string" {
  value     = "postgresql+psycopg2://${urlencode(var.db_username)}:${urlencode(var.db_password)}@${aws_db_instance.this.address}:5432/${var.db_name}"
  sensitive = true
}
