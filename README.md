Infrastructure Setup with Terraform
This repository sets up secure and scalable infrastructure on AWS using Terraform.

Prerequisites
Terraform

AWS CLI

Git

IAM permissions to manage EC2, RDS, S3, ACM, Secrets Manager, and KMS

SSL Certificates:

Dev: AWS ACM

Demo: Namecheap (import manually)

Getting Started

1. Clone the Repository
bash
Copy
Edit
git clone https://github.com/your-organization/your-repo.git
cd your-repo/tf-aws-infra

2. Initialize Terraform
bash
Copy
Edit
terraform init

3. Set Variables
Create a terraform.tfvars file:

hcl
Copy
Edit
environment = "demo"
region = "us-east-1"
key_name = "your-key-pair"
vpc_cidr = "10.0.0.0/16"
db_username = "csye6225"
db_name = "csye6225"
app_port = 8080

4. Apply Infrastructure
bash
Copy
Edit
terraform plan -var-file=demo.tfvars
terraform apply -var-file=demo.tfvars
Infrastructure Components
VPC with public and private subnets

Auto Scaling Group behind an Application Load Balancer

EC2 instances auto-configured with application via user-data

RDS MySQL Database encrypted with KMS

S3 Bucket (KMS-encrypted)

Secrets Manager for database credentials

SSL Certificates for secure load balancer access

CloudWatch Alarms for Auto-Scaling

Secrets Management
Database credentials are stored in AWS Secrets Manager.

EC2 instances securely fetch secrets at boot.

Secrets are encrypted with KMS and rotated every 90 days.

SSL Certificates
Environment	Certificate Source
Dev	AWS Certificate Manager (ACM)
Demo	Namecheap (manual import)
Import Certificate Command:

bash
Copy
Edit
aws acm import-certificate \
  --certificate fileb://certificate.pem \
  --private-key fileb://private-key.pem \
  --certificate-chain fileb://certificate-chain.pem \
  --region us-east-1
GitHub Actions CI/CD Workflow
On Pull Request: Validate code and run tests

On Pull Request Merge:

Build AMI in Dev AWS Account

Share AMI with Demo Account

Switch AWS credentials to Demo

Update Launch Template

Start Auto-Scaling Group Instance Refresh

Wait for refresh to complete

GitHub Secrets used:

DEV_AWS_ACCESS_KEY_ID

DEV_AWS_SECRET_ACCESS_KEY

DEMO_AWS_ACCESS_KEY_ID

DEMO_AWS_SECRET_ACCESS_KEY

DB_HOST, DB_PASSWORD, S3_BUCKET

VPC_IDENTIFIER_DEV, SUBNET_IDENTIFIER_DEV

DEMO_ACCOUNT_ID_PKR

Monitoring
CloudWatch Metrics: CPU, Disk, Logs

CloudWatch Alarms: Auto-scale when CPU > 5% or < 3%

Troubleshooting
Issue	Solution
502 Bad Gateway	Check app running status on EC2 (systemctl)
App cannot connect to database	Check Secrets retrieval in .env
SSL errors on Load Balancer	Validate ACM certificate attachment
Instances unhealthy	Validate user-data script and app service
Best Practices
Use Infrastructure as Code (IaC) with Terraform

Encrypt all data at rest using KMS

Secure secrets with Secrets Manager

Enforce SSL across all environments

Automate AMI builds and instance updates

Enable KMS key rotation (90 days)

✅ Final Assignment 08 Requirements Checklist
Launch Template + Auto Scaling Group ✅

Pull Request triggers GitHub Actions ✅

Merge triggers AMI build, share, and instance refresh ✅

KMS encryption for EC2, RDS, S3, Secrets Manager ✅

Secrets managed securely ✅

SSL/TLS setup complete for Load Balancer ✅

Healthy Load Balancer Targets ✅