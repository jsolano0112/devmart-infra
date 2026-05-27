output "alb_dns" {
  description = "DNS del Application Load Balancer"
  value       = aws_lb.devmart.dns_name
}

output "app_url" {
  description = "URL de acceso a la aplicacion"
  value       = "http://${aws_lb.devmart.dns_name}"
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.devmart.name
}

output "service_discovery_namespace" {
  description = "Namespace DNS interno de los servicios"
  value       = aws_service_discovery_private_dns_namespace.devmart.name
}

output "infra_git_branch" {
  value = "develop"
}
