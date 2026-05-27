variable "aws_region" {
  description = "Region AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT Secret"
  type        = string
  sensitive   = true
}

variable "jwt_expire_in" {
  description = "JWT expiration"
  type        = string
  default     = "15m"
}

variable "jwt_refresh_secret" {
  description = "JWT Refresh Secret"
  type        = string
  sensitive   = true
}

variable "jwt_refresh_expire_in" {
  description = "JWT Refresh expiration"
  type        = string
  default     = "20m"
}

variable "db_username" {
  description = "MongoDB username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "MongoDB password"
  type        = string
  sensitive   = true
}

variable "aws_s3_bucket" {
  description = "S3 bucket name"
  type        = string
}
