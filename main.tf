# Define the AWS provider with region and profile from variables
provider "aws" {
  region  = var.region
  profile = var.profile
}

# Fetch available AZs dynamically
data "aws_availability_zones" "zones" {
  state = "available"
}

# Create a Virtual Private Cloud (VPC)
resource "aws_vpc" "network" {
  cidr_block = var.network_cidr

  tags = {
    Name = "Custom-Network"
  }
}

# Create an Internet Gateway for public internet access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "Custom-IGW"
  }
}

# Create Public Subnets dynamically in different AZs
resource "aws_subnet" "accessible" {
  count = var.subnet_count

  vpc_id                  = aws_vpc.network.id
  cidr_block              = cidrsubnet(var.network_cidr, 8, count.index) # Auto-calculates CIDR blocks
  availability_zone       = element(data.aws_availability_zones.zones.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "Accessible-Subnet-${count.index + 1}"
  }
}

# Create Private Subnets dynamically in different AZs
resource "aws_subnet" "restricted" {
  count = var.subnet_count

  vpc_id            = aws_vpc.network.id
  cidr_block        = cidrsubnet(var.network_cidr, 8, count.index + var.subnet_count) # Different range from public
  availability_zone = element(data.aws_availability_zones.zones.names, count.index)

  tags = {
    Name = "Restricted-Subnet-${count.index + 1}"
  }
}

# Create a Route Table for Public Subnets
resource "aws_route_table" "accessible_rt" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "Accessible-Route-Table"
  }
}

# Add default route to the Internet Gateway for public subnets
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.accessible_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "accessible_rta" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.accessible[*].id, count.index)
  route_table_id = aws_route_table.accessible_rt.id
}

# Create Private Route Table Private Subnets
resource "aws_route_table" "restricted_rt" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "Restricted-Route-Table"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "restricted_rta" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.restricted[*].id, count.index)
  route_table_id = aws_route_table.restricted_rt.id
}

# Security Group for Application allowing public access
# Application Security Group 
resource "aws_security_group" "application_sg" {
  vpc_id = aws_vpc.network.id

  # Keep SSH for admin access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Only allow traffic from the load balancer on application port
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Custom-Network-Application-SG"
  }
}

resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.accessible[0].id
  vpc_security_group_ids = [aws_security_group.application_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.existing_profile.name

  user_data = <<-EOF
  #!/bin/bash
  # Create application directory if it doesn't exist
  mkdir -p /opt/webapp
  
  # Install CloudWatch agent
  wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  dpkg -i amazon-cloudwatch-agent.deb
  
  # Configure CloudWatch agent
  cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWAGENTCONFIG'
  {
    "agent": {
      "metrics_collection_interval": 60,
      "run_as_user": "root"
    },
    "logs": {
      "logs_collected": {
        "files": {
          "collect_list": [
            {
              "file_path": "/opt/webapp/logs/application.log",
              "log_group_name": "webapp-logs",
              "log_stream_name": "{instance_id}-application",
              "retention_in_days": 7
            },
            {
              "file_path": "/opt/webapp/logs/error.log",
              "log_group_name": "webapp-logs",
              "log_stream_name": "{instance_id}-error",
              "retention_in_days": 7
            }
          ]
        }
      }
    },
    "metrics": {
      "namespace": "WebApp",
      "metrics_collected": {
        "statsd": {
          "service_address": ":8125",
          "metrics_collection_interval": 10,
          "metrics_aggregation_interval": 60
        }
      }
    }
  }
  CWAGENTCONFIG
  
  # Start CloudWatch agent
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  
  # Create environment file
  cat > /opt/webapp/.env << ENVEOF
  DB_HOST=${aws_db_instance.webapp_db.address}
  DB_PORT=${var.db_port}
  DB_USER=${var.db_username}
  DB_PASSWORD=${var.db_password}
  DB_NAME=${var.db_name}
  AWS_REGION=${var.region}
  S3_BUCKET=${aws_s3_bucket.webapp_bucket.bucket}
  PORT=${var.app_port}
  NODE_ENV=production
  LOG_DIRECTORY=/opt/webapp/logs
  ENVEOF
  
  # Create directories
  mkdir -p /opt/webapp/logs
  chmod 755 /opt/webapp/logs
  
  # Set proper permissions
  chmod 600 /opt/webapp/.env
  chown webapp:webapp /opt/webapp/.env
  chown webapp:webapp /opt/webapp/logs
  
  # Restart application service
  systemctl restart webapp
EOF

  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  disable_api_termination = false

  tags = {
    Name = "WebApp-EC2-Instance"
  }
}

# S3 Bucket with UUID name
resource "random_uuid" "bucket_uuid" {}

resource "aws_s3_bucket" "webapp_bucket" {
  bucket        = "csye6225-${random_uuid.bucket_uuid.result}"
  force_destroy = true

  tags = {
    Name = "WebApp-S3-Bucket"
  }
}

# S3 Private Access Configuration
resource "aws_s3_bucket_public_access_block" "webapp_bucket_access" {
  bucket = aws_s3_bucket.webapp_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Default Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "webapp_bucket_encryption" {
  bucket = aws_s3_bucket.webapp_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "webapp_bucket_lifecycle" {
  bucket = aws_s3_bucket.webapp_bucket.id

  rule {
    id     = "transition-to-standard-ia"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}


# Database Security Group
resource "aws_security_group" "database_sg" {
  name        = "database-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.network.id

  # Allow traffic from the application security group
  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.application_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database Security Group"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "csye6225-db-subnet-group"
  subnet_ids = aws_subnet.restricted[*].id

  tags = {
    Name = "WebApp DB Subnet Group"
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "db_parameter_group" {
  name   = "csye6225-db-param-group"
  family = "mysql8.0"

  tags = {
    Name = "WebApp DB Parameter Group"
  }
}

# RDS Instance
resource "aws_db_instance" "webapp_db" {
  identifier             = var.db_name
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = aws_db_parameter_group.db_parameter_group.name
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "WebApp RDS Instance"
  }
}

# IAM Role for EC2 to access S3
resource "aws_iam_role" "ec2_s3_access" {
  name = "ec2_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# S3 Access Policy
resource "aws_iam_policy" "s3_access_policy" {
  name        = "s3_access_policy"
  description = "Policy allowing EC2 to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.webapp_bucket.arn,
          "${aws_s3_bucket.webapp_bucket.arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Access Policy
resource "aws_iam_policy" "cloudwatch_access_policy" {
  name        = "cloudwatch_access_policy"
  description = "Policy allowing EC2 to send logs and metrics to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Attach CloudWatch Policy to Role
resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = aws_iam_policy.cloudwatch_access_policy.arn
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "existing_profile" {
  name = "ec2_s3_profile_new"
  role = aws_iam_role.ec2_s3_access.name
}