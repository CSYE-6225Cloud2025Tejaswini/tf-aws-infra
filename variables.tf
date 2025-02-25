
variable "region" {
  description = "Region for deploying resources"
  type        = string
  default     = "us-east-1" # Default AWS Region
}

variable "profile" {
  description = "CLI Profile for authentication"
  type        = string
  default     = "demo" # AWS CLI default profile
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