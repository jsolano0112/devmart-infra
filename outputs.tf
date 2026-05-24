output "ec2_public_ip" {
  value       = aws_eip.devmart_ip.public_ip
  description = "IP fija del servidor"
}

output "ec2_ssh_command" {
  value       = "ssh -i ${var.key_name}-${terraform.workspace}.pem ubuntu@${aws_eip.devmart_ip.public_ip}"
  description = "Comando SSH"
}

output "environment" {
  value       = terraform.workspace
  description = "Ambiente activo"
}