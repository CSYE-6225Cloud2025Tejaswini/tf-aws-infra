variable "region" {
  description = "Region for deploying resources"
  type        = string
  default     = "us-east-1" # Default AWS Region
}

variable "profile" {
  description = "CLI Profile for authentication"
  type        = string
  default     = "profiledemo"
}

variable "network_cidr" {
  description = "CIDR block for the network"
  type        = string
  default     = "10.0.0.0/16" # Default VPC CIDR
}

variable "subnet_count" {
  description = "Number of subnets to create per category (public/private)"
  type        = number
  default     = 3 # Default to 3 subnets each for public & private
}

variable "ami_id" {
  description = "Custom AMI ID for EC2"
  type        = string
  default     = "ami-0b7d223d4c275c14e"
}

variable "key_name" {
  description = "SSH key pair name for EC2"
  type        = string
  default     = "ec2test"
}

variable "app_port" {
  description = "Port number on which the application runs"
  type        = number
  default     = 8080
}


variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "csye6225"
}

variable "db_username" {
  description = "Username for database access"
  type        = string
  default     = "csye6225"
}

variable "db_password" {
  description = "Password for database access"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Port for database connection"
  type        = number
  default     = 3306
}