# outputs.tf
output "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  value       = aws_s3_bucket.webapp_bucket.bucket
}

output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.webapp_db.address
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_instance.web.public_ip}:${var.app_port}"
}