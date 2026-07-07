terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # State stored in your existing S3 bucket
  backend "s3" {
    bucket  = "<YOUR_BUCKET_NAME>"
    key     = "<YOUR_KEY_NAME>"
    region  = "<YOUR_REGION>"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Secrets Manager — pull all sensitive values at plan/apply time ─────────────
data "aws_secretsmanager_secret" "app" {
  name = var.secret_name
}

data "aws_secretsmanager_secret_version" "app" {
  secret_id = data.aws_secretsmanager_secret.app.id
}

locals {
  secrets = jsondecode(data.aws_secretsmanager_secret_version.app.secret_string)
}

# ── Networking ────────────────────────────────────────────────────────────────
module "networking" {
  source               = "./modules/networking"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                  = var.azs
}

# ── Security Groups ───────────────────────────────────────────────────────────
module "security_groups" {
  source       = "./modules/security_groups"
  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
}

# ── RDS MySQL ─────────────────────────────────────────────────────────────────
module "rds" {
  source             = "./modules/rds"
  project_name       = var.project_name
  private_subnet_ids = module.networking.private_subnet_ids
  db_sg_id           = module.security_groups.db_sg_id
  db_instance_class  = var.db_instance_class
  db_name            = local.secrets["db_name"]     # from Secrets Manager
  db_username        = local.secrets["db_username"] # from Secrets Manager
  db_password        = local.secrets["db_password"] # from Secrets Manager
}

# ── Application Load Balancer ─────────────────────────────────────────────────
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
}

# ── Auto Scaling Group ────────────────────────────────────────────────────────
module "asg" {
  source             = "./modules/asg"
  project_name       = var.project_name
  private_subnet_ids = module.networking.private_subnet_ids
  ec2_sg_id          = module.security_groups.ec2_sg_id
  target_group_arn   = module.alb.target_group_arn
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  key_name           = var.key_name
  min_size           = var.asg_min_size
  max_size           = var.asg_max_size
  desired_capacity   = var.asg_desired_capacity
  s3_bucket          = var.s3_bucket
  secret_name        = var.secret_name # EC2 fetches secrets itself at boot
  db_host            = module.rds.db_endpoint
  app_url            = "http://${module.alb.alb_dns_name}"
  aws_region         = var.aws_region
}
