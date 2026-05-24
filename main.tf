terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

locals {
  env = terraform.workspace

  config = {
    qa = {
      instance_type = "t3.micro"
      volume_size   = 20
      git_branch    = "develop"
    }
    prod = {
      instance_type = "t3.small"
      volume_size   = 30
      git_branch    = "main"
    }
  }

  current = local.config[local.env]
}

# ─── KEY PAIR ──────────────────────────────────────

resource "tls_private_key" "devmart_key" {  
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "devmart_key_pair" { 
  key_name   = "${var.key_name}-${local.env}"
  public_key = tls_private_key.devmart_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.devmart_key.private_key_pem
  filename        = "${var.key_name}-${local.env}.pem"
  file_permission = "0400"
}

# ─── SECURITY GROUP ────────────────────────────────

resource "aws_security_group" "devmart_sg" {
  name        = "devmart-sg-${local.env}"
  description = "Security group for Devmart ${local.env}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  tags = { Name = "devmart-sg-${local.env}" }
}

# ─── EC2 ───────────────────────────────────────────

resource "aws_instance" "devmart" {
  ami                    = "ami-091138d0f0d41ff90"
  instance_type          = local.current.instance_type
  key_name               = aws_key_pair.devmart_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.devmart_sg.id]

  root_block_device {
    volume_size = local.current.volume_size
    volume_type = "gp2"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y

    # Swap memory
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # Instalar Docker
    apt-get install -y docker.io git
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu

     # Instalar Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

     # Clonar devmart-infra
    cd /home/ubuntu
    git clone -b ${local.current.git_branch} https://github.com/jsolano0112/devmart-infra.git
    cd devmart-infra

    # Crear .env
    cat > .env << 'ENVFILE'
    ENVIRONMENT=${local.env}
    JWT_SECRET=${var.jwt_secret}
    JWT_EXPIRE_IN=15m
    JWT_REFRESH_SECRET=${var.jwt_refresh_secret}
    JWT_REFRESH_EXPIRE_IN=20m
    DB_USERNAME=${var.db_username}
    DB_PASSWORD=${var.db_password}
    SOCKET_SERVER_URL=http://websocket-1:5000
    REACT_APP_DEVMART_API=/api/v1/
    REACT_APP_USERS_API=/api/v1/
    REACT_APP_NOTIFICATIONS_API=/api/v1/
    REACT_APP_SOCKET_SERVER_URL=http://localhost:4000
    ENVFILE

    # Levantar servicios
    docker-compose up -d
  EOF

  tags = {
    Name        = "devmart-server-${local.env}"
    Environment = local.env
  }

  lifecycle {
    ignore_changes = [user_data]
  }

  provisioner "remote-exec" {
    inline = ["echo 'EC2 ${local.env} lista'"]
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = tls_private_key.devmart_key.private_key_pem
    }
  }
}

# ─── IP FIJA ───────────────────────────────────────

resource "aws_eip" "devmart_ip" {
  instance = aws_instance.devmart.id
  tags     = { Name = "devmart-eip-${local.env}" }

  lifecycle {
    prevent_destroy = true
  }
}