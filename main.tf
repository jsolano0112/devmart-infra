terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "devmart-terraform-state"
    key    = "ecs/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

locals {
  cpu         = 256
  memory      = 512
  api_desired = 1

  common_tags = {
    Environment = "qa"
    Project     = "devmart"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# VPC y Networking
# -----------------------------------------------------------------------------

resource "aws_vpc" "devmart" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, { Name = "devmart-vpc" })
}

resource "aws_internet_gateway" "devmart" {
  vpc_id = aws_vpc.devmart.id
  tags   = merge(local.common_tags, { Name = "devmart-igw" })
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.devmart.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "devmart-subnet-public-a" })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.devmart.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "devmart-subnet-public-b" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.devmart.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devmart.id
  }

  tags = merge(local.common_tags, { Name = "devmart-rt-public" })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "devmart-sg-alb"
  description = "ALB - trafico publico"
  vpc_id      = aws_vpc.devmart.id

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

  tags = merge(local.common_tags, { Name = "devmart-sg-alb" })
}

resource "aws_security_group" "nginx" {
  name        = "devmart-sg-nginx"
  description = "nginx - solo trafico desde ALB"
  vpc_id      = aws_vpc.devmart.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "devmart-sg-nginx" })
}

resource "aws_security_group" "ecs_tasks" {
  name        = "devmart-sg-ecs"
  description = "ECS tasks - solo trafico desde nginx"
  vpc_id      = aws_vpc.devmart.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "devmart-sg-ecs" })
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "devmart" {
  name = "devmart-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, { Name = "devmart-cluster" })
}

resource "aws_ecs_cluster_capacity_providers" "devmart" {
  cluster_name       = aws_ecs_cluster.devmart.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# -----------------------------------------------------------------------------
# IAM Role para ECS
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ecs_execution" {
  name = "devmart-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_policy" {
  name = "devmart-ecs-execution-policy"
  role = aws_iam_role.ecs_execution.id 

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-1:919968176176:secret:devmart-secrets-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Application Load Balancer - nginx
# -----------------------------------------------------------------------------

resource "aws_lb" "devmart" {
  name               = "devmart-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = merge(local.common_tags, { Name = "devmart-alb" })
}

resource "aws_lb_target_group" "nginx" {
  name        = "devmart-tg-nginx"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.devmart.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = merge(local.common_tags, { Name = "devmart-tg-nginx" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.devmart.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}