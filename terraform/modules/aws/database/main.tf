resource "aws_security_group" "database" {
  name        = "${var.environment}-rds-sg"
  description = "Permit PostgreSQL from this VPC only"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_db_instance" "this" {
  identifier                 = "${var.environment}-ideas-db"
  engine                     = "postgres"
  engine_version             = "15"
  instance_class             = var.instance_class
  allocated_storage          = 20
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = var.db_password
  db_subnet_group_name       = aws_db_subnet_group.this.name
  vpc_security_group_ids     = [aws_security_group.database.id]
  publicly_accessible        = false
  storage_encrypted          = true
  backup_retention_period    = 7
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${var.environment}-ideas-db-final"
  deletion_protection        = true
  auto_minor_version_upgrade = true

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}
