terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket = "devmart-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

locals {
  env = terraform.workspace

  env_config = {
    qa = {
      instance_type = "t3.micro"
      volume_size   = 20
      git_branch    = "develop"
      app_port      = 4000
    }
    prod = {
      instance_type = "t3.small"
      volume_size   = 30
      git_branch    = "main"
      app_port      = 4000
    }
  }

  current = local.env_config[local.env]
}

# -----------------------------------------------------------------------------#
# AMI Ubuntu LTS (us-east-1)
# -----------------------------------------------------------------------------#

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------#
# Llave SSH (una por workspace: devmart-key-qa, devmart-key-prod)
# -----------------------------------------------------------------------------#

resource "tls_private_key" "devmart" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "devmart" {
  key_name   = "${var.key_name}-${local.env}"
  public_key = tls_private_key.devmart.public_key_openssh

  lifecycle {
    ignore_changes = [public_key]
  }

  tags = {
    Name        = "${var.key_name}-${local.env}"
    Environment = local.env
  }
}

resource "local_file" "private_key" {
  content              = tls_private_key.devmart.private_key_pem
  filename             = "${path.module}/${var.key_name}-${local.env}.pem"
  file_permission      = "0600"
  directory_permission = "0700"
}

# -----------------------------------------------------------------------------#
# Security Group
# Puertos: 22 (SSH), 4000 (nginx gateway -> microservicios)
# -----------------------------------------------------------------------------#

resource "aws_security_group" "devmart" {
  name        = "devmart-sg-${local.env}"
  description = "Devmart ${local.env} - SSH y API Gateway"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  ingress {
    description = "Nginx gateway (UI + APIs + WebSocket)"
    from_port   = local.current.app_port
    to_port     = local.current.app_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_app_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devmart-sg-${local.env}"
    Environment = local.env
    Project     = "devmart"
  }
}

# ─── EC2 ───────────────────────────────────────────

resource "aws_instance" "devmart" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.current.instance_type
  key_name               = aws_key_pair.devmart.key_name
  vpc_security_group_ids = [aws_security_group.devmart.id]

  root_block_device {
    volume_size = local.current.volume_size
    volume_type = "gp2"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eu
    exec > /var/log/devmart-bootstrap.log 2>&1

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y docker.io git curl ca-certificates

    if [ ! -f /swapfile ]; then
      fallocate -l 1G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu

    curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    mkdir -p /home/ubuntu/devmart-infra
    chown -R ubuntu:ubuntu /home/ubuntu/devmart-infra

    echo "Bootstrap ${local.env} completado" >> /var/log/devmart-bootstrap.log
  EOF

  tags = {
    Name        = "devmart-server-${local.env}"
    Environment = local.env
    Project     = "devmart"
    GitBranch   = local.current.git_branch
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

# -----------------------------------------------------------------------------#
# Elastic IP fija por ambiente
# -----------------------------------------------------------------------------#

resource "aws_eip" "devmart" {
  instance = aws_instance.devmart.id
  vpc      = true

  tags = {
    Name        = "devmart-eip-${local.env}"
    Environment = local.env
    Project     = "devmart"
  }

  lifecycle {
    prevent_destroy = true
  }
}
