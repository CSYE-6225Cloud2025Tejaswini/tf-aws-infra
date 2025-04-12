# Define the AWS region where resources will be deployed
variable "region" {
  description = "Region for deploying resources"
  type        = string
  default     = "us-east-1" # Default AWS Region
}

# Define the AWS CLI profile for authentication
variable "profile" {
  description = "CLI Profile for authentication"
  type        = string
  default     = "profiledemo"
}

# Define the CIDR block for the Virtual Private Cloud (VPC)
variable "network_cidr" {
  description = "CIDR block for the network"
  type        = string
  default     = "10.0.0.0/16" # Default VPC CIDR
}

# Number of public and private subnets to create
variable "subnet_count" {
  description = "Number of subnets to create per category (public/private)"
  type        = number
  default     = 3 # Default to 3 subnets each for public & private
}
# Amazon Machine Image (AMI) ID for EC2 instances
variable "ami_id" {
  description = "Custom AMI ID for EC2"
  type        = string
  default     = "ami-0a43950b2d34e59f3"
}

# SSH Key Pair name for EC2 instances
variable "key_name" {
  description = "SSH key pair name for EC2"
  type        = string
  default     = "ec2test"
}

# Application Port Configuration
variable "app_port" {
  description = "Port number on which the application runs"
  type        = number
  default     = 8080
}


# Database Configuration Variables
variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

# Name of the database
variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "csye6225"
}

# Username for database authentication
variable "db_username" {
  description = "Username for database access"
  type        = string
  default     = "csye6225"
}

# Password for database authentication (marked as sensitive for security)
variable "db_password" {
  description = "Password for database access"
  type        = string
  sensitive   = true
}

# Port number for database connection
variable "db_port" {
  description = "Port for database connection"
  type        = number
  default     = 3306
}
variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}