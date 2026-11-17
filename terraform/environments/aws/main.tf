terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "idea-board-tfstate-aws"
    key          = "aws/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}

module "networking" {
  source       = "../../modules/aws/networking"
  environment  = var.environment
  cidr_block   = var.vpc_cidr
  cluster_name = var.cluster_name
}

module "cluster" {
  source              = "../../modules/aws/cluster"
  cluster_name        = var.cluster_name
  environment         = var.environment
  node_count          = var.node_count
  node_type           = var.node_type
  subnet_ids          = module.networking.subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids
  public_access_cidrs = var.control_plane_authorized_cidrs
}

module "database" {
  source         = "../../modules/aws/database"
  environment    = var.environment
  db_name        = "ideas"
  db_username    = "ideas_user"
  db_password    = var.db_password
  instance_class = var.db_instance_class
  vpc_id         = module.networking.vpc_id
  subnet_ids     = module.networking.subnet_ids
  vpc_cidr       = var.vpc_cidr
}

resource "aws_ecr_repository" "backend" {
  name                 = "idea-board-backend"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "idea-board-frontend"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
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

output "backend_image_repository" {
  value = aws_ecr_repository.backend.repository_url
}

output "frontend_image_repository" {
  value = aws_ecr_repository.frontend.repository_url
}
