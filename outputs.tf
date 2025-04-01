# outputs.tf

# Define Terraform output values for key infrastructure components

# Output the name of the created S3 bucket
output "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  value       = aws_s3_bucket.webapp_bucket.bucket
}

# Output the endpoint (DNS name) of the provisioned RDS database instance
output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = aws_db_instance.webapp_db.address
}


# Output the public IP address of the deployed EC2 instance
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}

# Construct and output the application URL using the EC2 public IP and application port
output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_instance.web.public_ip}:${var.app_port}"
}