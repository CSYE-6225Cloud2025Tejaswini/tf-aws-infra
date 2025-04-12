# KMS key for Secrets Manager
# Store database password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password_secret" {
  name        = "db-password-${var.environment}-1"
  description = "Database password for RDS instance"
  kms_key_id  = aws_kms_key.secrets_key.arn  # Keep this line using the resource from kms.tf
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id     = aws_secretsmanager_secret.db_password_secret.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.webapp_db.address
    port     = var.db_port
    dbname   = var.db_name
  })
}

# Generate a random password for the database
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}