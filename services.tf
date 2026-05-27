locals {
  api_secrets = [
    { name = "JWT_SECRET",             valueFrom = "${aws_secretsmanager_secret.devmart.arn}:JWT_SECRET::" },
    { name = "JWT_EXPIRE_IN",          valueFrom = "${aws_secretsmanager_secret.devmart.arn}:JWT_EXPIRE_IN::" },
    { name = "JWT_REFRESH_SECRET",     valueFrom = "${aws_secretsmanager_secret.devmart.arn}:JWT_REFRESH_SECRET::" },
    { name = "JWT_REFRESH_EXPIRE_IN", valueFrom = "${aws_secretsmanager_secret.devmart.arn}:JWT_REFRESH_EXPIRE_IN::" },
    { name = "DB_USERNAME",           valueFrom = "${aws_secretsmanager_secret.devmart.arn}:DB_USERNAME::" },
    { name = "DB_PASSWORD",           valueFrom = "${aws_secretsmanager_secret.devmart.arn}:DB_PASSWORD::" },
    { name = "AWS_ACCESS_KEY_ID",     valueFrom = "${aws_secretsmanager_secret.devmart.arn}:AWS_ACCESS_KEY_ID::" },
    { name = "AWS_SECRET_ACCESS_KEY", valueFrom = "${aws_secretsmanager_secret.devmart.arn}:AWS_SECRET_ACCESS_KEY::" },
    { name = "AWS_REGION",            valueFrom = "${aws_secretsmanager_secret.devmart.arn}:AWS_REGION::" },
    { name = "AWS_S3_BUCKET",         valueFrom = "${aws_secretsmanager_secret.devmart.arn}:AWS_S3_BUCKET::" },
  ]
}

# =============================================================================
# DEVMART-API
# =============================================================================

resource "aws_ecs_task_definition" "api" {
  family                   = "devmart-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.cpu
  memory                   = local.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "devmart-api"
    image     = "jsolano0112/devmart-api:latest"
    essential = true

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    secrets = local.api_secrets

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/devmart-api"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
        "awslogs-create-group"  = "true"
      }
    }
  }])

  tags = merge(local.common_tags, { Name = "devmart-api-task" })
}

resource "aws_ecs_service" "api" {
  name            = "devmart-api"
  cluster         = aws_ecs_cluster.devmart.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = local.api_desired
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.api.arn
  }

  tags = merge(local.common_tags, { Name = "devmart-api-service" })
}

# =============================================================================
# USERS-API
# =============================================================================

resource "aws_ecs_task_definition" "users" {
  family                   = "users-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.cpu
  memory                   = local.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "users-api"
    image     = "jsolano0112/users-api:latest"
    essential = true

    portMappings = [{
      containerPort = 3001
      protocol      = "tcp"
    }]

    secrets = local.api_secrets

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/users-api"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
        "awslogs-create-group"  = "true"
      }
    }
  }])

  tags = merge(local.common_tags, { Name = "users-api-task" })
}

resource "aws_ecs_service" "users" {
  name            = "users-api"
  cluster         = aws_ecs_cluster.devmart.id
  task_definition = aws_ecs_task_definition.users.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.users.arn
  }

  tags = merge(local.common_tags, { Name = "users-api-service" })
}

# =============================================================================
# DEVMART-UI (Contenedor unificado: Frontend React + Nginx proxy)
# =============================================================================

resource "aws_ecs_task_definition" "ui" {
  family                   = "devmart-ui"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.cpu
  memory                   = local.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name      = "devmart-ui"
    image     = "jsolano0112/devmart-ui:latest"
    essential = true

    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/devmart-ui"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
        "awslogs-create-group"  = "true"
      }
    }
  }])

  tags = merge(local.common_tags, { Name = "devmart-ui-task" })
}

resource "aws_ecs_service" "ui" {
  name            = "devmart-ui"
  cluster         = aws_ecs_cluster.devmart.id
  task_definition = aws_ecs_task_definition.ui.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  
    security_groups  = [aws_security_group.nginx.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx.arn
    container_name   = "devmart-ui"
    container_port   = 80
  }

  service_registries {
    registry_arn = aws_service_discovery_service.ui.arn
  }

  tags = merge(local.common_tags, { Name = "devmart-ui-service" })
}

# =============================================================================
# SERVICE DISCOVERY (Cloud Map) - DNS Interno
# =============================================================================

resource "aws_service_discovery_private_dns_namespace" "devmart" {
  name        = "devmart.local"
  description = "DNS interno para servicios devmart"
  vpc         = aws_vpc.devmart.id

  tags = local.common_tags
}

resource "aws_service_discovery_service" "api" {
  name = "devmart-api"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.devmart.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "users" {
  name = "users-api"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.devmart.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "ui" {
  name = "devmart-ui"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.devmart.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}