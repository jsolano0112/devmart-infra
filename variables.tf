variable "aws_region" {
  default = "us-east-1"
}

variable "key_name" {
  default = "devmart-key"
}

variable "aws_access_key" {
  description = "AWS Access Key"
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT Secret"
  sensitive   = true
}

variable "jwt_refresh_secret" {
  description = "JWT Refresh Secret"
  sensitive   = true
}

variable "db_username" {
  description = "MongoDB username"
  sensitive   = true
}

variable "db_password" {
  description = "MongoDB password"
  sensitive   = true
}