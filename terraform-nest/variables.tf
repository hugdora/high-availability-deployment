# ── variables.tf ──────────────────────────────────────────────────────────────
# No sensitive values here — all secrets live in AWS Secrets Manager.

variable "aws_region" {
  description = "AWS region for all resources"
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Prefix applied to every resource name"
  default     = "nest-app"
}

variable "secret_name" {
  description = "Name of the Secrets Manager secret holding db credentials and app_key"
  default     = "nest-app/db-credentials"
}

# ── Network ───────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones — must match the region above"
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ) — ALB lives here"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ) — EC2 + RDS live here"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ── EC2 / ASG ─────────────────────────────────────────────────────────────────
variable "ami_id" {
  description = <<-EOT
    Amazon Linux 2023 AMI ID for eu-west-2.
    Run this command to get the latest:
      aws ec2 describe-images \
        --owners amazon \
        --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
        --query "sort_by(Images, &CreationDate)[-1].ImageId" \
        --output text --region eu-west-2
  EOT
}

variable "instance_type" {
  description = "EC2 instance type for the ASG"
  default     = "t3.small"
}

variable "key_name" {
  description = "EC2 key pair name — used for emergency SSH access within the VPC"
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances in the ASG"
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances the ASG can scale to"
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of EC2 instances at steady state"
  default     = 2
}

# ── Database ──────────────────────────────────────────────────────────────────
variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.micro"
}

# ── App ───────────────────────────────────────────────────────────────────────
variable "s3_bucket" {
  description = "S3 bucket containing Project-2-assets/ (nest.zip, V1__nest.sql, AppServiceProvider.php)"
  default     = "dev-app-dora-webfiles"
}
