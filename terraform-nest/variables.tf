# =============================================================================
# Terraform Variables
# =============================================================================
# This project deploys a highly available NestJS application on AWS.
#
# Copy terraform.tfvars.example to terraform.tfvars and update the values
# before running Terraform.
#
# terraform.tfvars should NOT be committed to Git.
# =============================================================================

############################
# AWS Configuration
############################

variable "aws_region" {
  description = "AWS region where resources will be created."
  type        = string
  default     = "eu-west-2" # CAN BE CHANGE
}

variable "project_name" {
  description = "Prefix used when naming AWS resources."
  type        = string
  default     = "nest-app" # CAN BE CHANGE
}

variable "secret_name" {
  description = "AWS Secrets Manager secret containing the application secrets."
  type        = string
}

############################
# Networking
############################

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16" # CAN BE CHANGE
}

variable "azs" {
  description = "Availability Zones used for the deployment."
  type        = list(string)

  default = [
    "eu-west-2a",
    "eu-west-2b"
  ]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets."
  type        = list(string)

  default = [    
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets."
  type        = list(string)

  default = [   
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]
}

############################
# EC2 & Auto Scaling
############################

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Existing EC2 Key Pair name."
  type        = string
}

variable "asg_min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances."
  type        = number
  default     = 2
}

############################
# Database
############################

variable "db_instance_class" {
  description = "Amazon RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

############################
# Application
############################

variable "s3_bucket" {
  description = "S3 bucket containing the application deployment files."
  type        = string
}