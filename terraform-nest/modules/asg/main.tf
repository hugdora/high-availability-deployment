variable "project_name" {}
variable "private_subnet_ids" {}
variable "ec2_sg_id" {}
variable "target_group_arn" {}
variable "ami_id" {}
variable "instance_type" { default = "t3.small" }
variable "key_name" {}
variable "min_size" { default = 1 }
variable "max_size" { default = 4 }
variable "desired_capacity" { default = 2 }
variable "s3_bucket" {}
variable "secret_name" {} # Secrets Manager secret name
variable "db_host" {}     # RDS endpoint — not sensitive (not a credential)
variable "app_url" {}
variable "aws_region" {}

# ── IAM Role ─────────────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# S3 — read app assets from your bucket
resource "aws_iam_role_policy" "s3_read" {
  name = "${var.project_name}-s3-read"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.s3_bucket}",
        "arn:aws:s3:::${var.s3_bucket}/*"
      ]
    }]
  })
}

# Secrets Manager — read the app secret at boot time
resource "aws_iam_role_policy" "secrets_read" {
  name = "${var.project_name}-secrets-read"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      # The trailing * covers the random suffix AWS appends to secret ARNs
      Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.secret_name}*"
    }]
  })
}

# SSM Session Manager — connect to instances without needing SSH open
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ── Launch Template ───────────────────────────────────────────────────────────
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false # EC2 stays in private subnet
    security_groups             = [var.ec2_sg_id]
  }

  # Only non-sensitive values are passed via templatefile
  # Credentials are fetched by the instance itself from Secrets Manager
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    S3_BUCKET   = var.s3_bucket
    SECRET_NAME = var.secret_name
    AWS_REGION  = var.aws_region
    DB_HOST     = var.db_host
    APP_URL     = var.app_url
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-instance" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Auto Scaling Group ────────────────────────────────────────────────────────
resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 900 # 15 min for bootstrap to complete

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Scaling Policy — Target Tracking on CPU ───────────────────────────────────
resource "aws_autoscaling_policy" "cpu_tracking" {
  name                   = "${var.project_name}-cpu-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0 # Scale out when average CPU exceeds 70%
  }
}

output "asg_name" { value = aws_autoscaling_group.app.name }
