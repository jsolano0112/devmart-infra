output "environment" {
  description = "Workspace activo (qa | prod)"
  value       = local.env
}

output "ec2_public_ip" {
  description = "IP publica (Elastic IP) del servidor"
  value       = aws_eip.devmart.public_ip
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.devmart.id
}

output "app_url" {
  description = "URL de acceso (nginx gateway)"
  value       = "http://${aws_eip.devmart.public_ip}:${local.current.app_port}"
}

output "ec2_ssh_command" {
  description = "Comando SSH de referencia"
  value       = "ssh -i ${var.key_name}-${local.env}.pem ubuntu@${aws_eip.devmart.public_ip}"
}

output "infra_git_branch" {
  description = "Rama de devmart-infra que usa este ambiente"
  value       = local.current.git_branch
}

output "key_pair_name" {
  description = "Nombre del key pair en AWS"
  value       = aws_key_pair.devmart.key_name
}

output "private_key_filename" {
  description = "Archivo PEM generado localmente tras apply"
  value       = local_file.private_key.filename
}
