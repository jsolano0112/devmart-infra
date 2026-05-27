resource "aws_secretsmanager_secret" "devmart" {
  name        = "devmart-secrets-qa"
  description = "Contenedor de secretos para devmart"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "devmart" {
  secret_id = aws_secretsmanager_secret.devmart.id

  secret_string = jsonencode({
    JWT_SECRET            = var.jwt_secret
    JWT_EXPIRE_IN         = var.jwt_expire_in
    JWT_REFRESH_SECRET    = var.jwt_refresh_secret
    JWT_REFRESH_EXPIRE_IN = var.jwt_refresh_expire_in
    DB_USERNAME           = var.db_username
    DB_PASSWORD           = var.db_password
    AWS_ACCESS_KEY_ID     = var.aws_access_key
    AWS_SECRET_ACCESS_KEY = var.aws_secret_key
    AWS_REGION            = var.aws_region
    AWS_S3_BUCKET         = var.aws_s3_bucket
  })
}