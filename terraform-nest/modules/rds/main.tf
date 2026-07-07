variable "project_name" {}
variable "private_subnet_ids" {}
variable "db_sg_id" {}
variable "db_instance_class" { default = "db.t3.micro" }
variable "db_name" { sensitive = true }
variable "db_username" { sensitive = true }
variable "db_password" { sensitive = true }

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.project_name}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_sg_id]

  # Snapshot & protection — enable in production
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 7
  multi_az                = false # Set true in production

  tags = { Name = "${var.project_name}-mysql" }
}

# Strip the :3306 port suffix — Laravel only wants the hostname
output "db_endpoint" {
  value = split(":", aws_db_instance.mysql.endpoint)[0]
}
