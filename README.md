# Infrastructure Setup with Terraform

This repository contains Terraform configurations to provision and manage our infrastructure as code. Below you'll find instructions for setting up, configuring, and deploying infrastructure using Terraform.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (v1.0.0 or later)
- AWS CLI configured with appropriate credentials
- Git

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/your-organization/your-repo.git
cd your-repo/terraform
```

### 2. Initialize Terraform

```bash
terraform init
```

This will download the necessary providers and initialize the Terraform working directory.

### 3. Configure Environment Variables

Create a `terraform.tfvars` file in the terraform directory:

```hcl
# Infrastructure Settings
environment = "dev" # Options: dev, staging, prod

# AWS Configuration
aws_region = "us-west-2"
vpc_cidr   = "10.0.0.0/16"

# Database Configuration
db_instance_type = "db.t3.medium"
db_name          = "appdb"
db_user          = "dbadmin"
# db_password should be set via environment variable TF_VAR_db_password

# Application Settings
app_instance_type = "t3.medium"
app_instance_count = 2
```

For sensitive values, use environment variables:

```bash
export TF_VAR_db_password="your-secure-password"
```

### 4. Review the Execution Plan

```bash
terraform plan
```

This will show you what changes Terraform will make to your infrastructure.

### 5. Apply Changes

```bash
terraform apply
```

Review the plan one more time and type `yes` to confirm.

## Available Modules

### Networking

Sets up VPC, subnets, route tables, and security groups.

```hcl
module "networking" {
  source = "./modules/networking"
  
  vpc_cidr = var.vpc_cidr
  environment = var.environment
}
```

### Database

Provisions RDS instances.

```hcl
module "database" {
  source = "./modules/database"
  
  instance_type = var.db_instance_type
  db_name = var.db_name
  db_user = var.db_user
  db_password = var.db_password
  subnet_ids = module.networking.private_subnet_ids
  security_group_ids = [module.networking.db_security_group_id]
}
```

### Compute

Sets up application servers or containers.

```hcl
module "compute" {
  source = "./modules/compute"
  
  instance_type = var.app_instance_type
  instance_count = var.app_instance_count
  subnet_ids = module.networking.private_subnet_ids
  security_group_ids = [module.networking.app_security_group_id]
}
```

## Continuous Integration

This repository is configured with GitHub Actions to validate Terraform configurations on every pull request. The workflow:

1. Runs `terraform validate` to check syntax
2. Runs `terraform plan` to verify changes
3. Comments the plan output on the PR

## State Management

We use an S3 backend for storing Terraform state remotely:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "terraform-state-lock"
    encrypt = true
  }
}
```

## Best Practices

1. **Never commit sensitive values** to Git. Use environment variables or a secure secrets manager.
2. **Always run `terraform plan`** before applying changes.
3. **Use modules** for reusable components.
4. **Tag all resources** for better organization and cost tracking.
5. **Use workspaces** for managing multiple environments with the same configuration.

## Troubleshooting

### Common Issues

1. **Credential errors**: Ensure your AWS credentials are properly configured
   ```bash
   aws configure
   ```

2. **State lock errors**: If a previous Terraform command was interrupted
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

3. **Provider version conflicts**: Update your Terraform version or specify provider versions
   ```hcl
   terraform {
     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = "~> 4.0"
       }
     }
   }
   ```

## Contributing

1. Create a feature branch from `main`
2. Make your changes
3. Run `terraform fmt` to standardize code formatting
4. Run `terraform validate` to check for errors
5. Submit a pull request

## Security Considerations

- Restrict IAM permissions to the minimum required
- Enable encryption for all sensitive data
- Use private subnets for resources that don't need public access
- Implement security groups with least privilege access