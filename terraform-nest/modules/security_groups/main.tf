variable "project_name" {}
variable "vpc_id" {}

# ── ALB SG — accepts HTTP from the internet ───────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP from internet to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# ── EC2 SG — only ALB can send traffic to port 80 ────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow HTTP from ALB only; SSH from within VPC"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH from within VPC (use SSM in production)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ec2-sg" }
}

# ── RDS SG — only EC2 can reach MySQL ────────────────────────────────────────
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow MySQL 3306 from EC2 only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EC2 only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-db-sg" }
}

output "alb_sg_id" { value = aws_security_group.alb.id }
output "ec2_sg_id" { value = aws_security_group.ec2.id }
output "db_sg_id" { value = aws_security_group.db.id }
