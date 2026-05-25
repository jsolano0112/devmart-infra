variable "aws_region" {
  description = "Region AWS"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Prefijo del key pair (sufijo = workspace: qa | prod)"
  type        = string
  default     = "devmart-key"
}

variable "write_private_key_file" {
  description = "Generar archivo .pem local. En Jenkins usar false (credencial SSH)."
  type        = bool
  default     = false
}

variable "aws_access_key" {
  description = "AWS Access Key (Jenkins: AWS_ACCESS_KEY_ID)"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key (Jenkins: AWS_SECRET_ACCESS_KEY)"
  type        = string
  sensitive   = true
}

# JWT y MongoDB se inyectan en el .env via stage "Deploy Stack" (Jenkins), no en Terraform.

variable "allowed_ssh_cidr" {
  description = "CIDR permitidos para SSH (puerto 22)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_app_cidr" {
  description = "CIDR permitidos para la app (puerto 4000)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
