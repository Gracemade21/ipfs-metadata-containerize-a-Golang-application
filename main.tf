terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  required_version = ">= 0.12"
}

provider "aws" {
 # region = var.aws_region
  region = "us-east-1"
}

# Define VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main"
  }
}

# Define Subnets

data "aws_availability_zones" "available" {}
resource "aws_subnet" "subnet" {
  count = 2
  vpc_id = aws_vpc.main.id
  # cidr_block = "10.0.1.${count.index * 128}/24"
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "subnet-${count.index}"
  }
}

# Define Security Group
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id
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
  tags = {
    Name = "app_sg"
  }
}

# Define ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "my-cluster"
}

# Define ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "my-app"
  container_definitions    = jsonencode([{
    name      = "my-container"
    image     = var.docker_image
    memory    = 512
    cpu       = 256
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
  }])
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
}

# Define ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "my-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 2
  launch_type     = "EC2"
}

# define parameter group
resource "aws_db_parameter_group" "custom_pg" {
  name        = "my-custom-parameter-group"
  family      = "postgres16"
  description = "My custom parameter group for PostgreSQL 16"

  parameter {
    name  = "max_connections"
    value = "200"
    apply_method = "pending-reboot"
  }
}

# Define RDS PostgreSQL Database
resource "aws_db_instance" "default" {
  identifier = "mydbinstance1"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  engine = "postgres"
  engine_version = "16.3"
  username = var.DB_USERNAME
  password = var.DB_PASSWORD
  parameter_group_name = aws_db_parameter_group.custom_pg.name
  skip_final_snapshot = true
  tags = {
    Name = "mydbinstance"
  }
}

variable "aws_region" {
  default = "us-east-1"
}

variable "docker_image" {
  description = "The Docker image to deploy"
}

variable "DB_USERNAME" {
  description = "The database username"
}

variable "DB_PASSWORD" {
  description = "The database password"
}

variable "db_name" {
  description = "The database name"
  default     = null
}
