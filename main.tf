provider "aws" {
  region  = var.region
  profile = var.profile
}

# Fetch available AZs dynamically
data "aws_availability_zones" "zones" {
  state = "available"
}

# Create VPC
resource "aws_vpc" "network" {
  cidr_block = var.network_cidr

  tags = {
    Name = "Custom-Network"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "Custom-IGW"
  }
}

# Create Public Subnets Dynamically
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

# Create Private Subnets Dynamically
resource "aws_subnet" "restricted" {
  count = var.subnet_count

  vpc_id            = aws_vpc.network.id
  cidr_block        = cidrsubnet(var.network_cidr, 8, count.index + var.subnet_count) # Different range from public
  availability_zone = element(data.aws_availability_zones.zones.names, count.index)

  tags = {
    Name = "Restricted-Subnet-${count.index + 1}"
  }
}

# Create Public Route Table
resource "aws_route_table" "accessible_rt" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "Accessible-Route-Table"
  }
}

# Add Internet Access Route
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

# Create Private Route Table
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

# Application Security Group
resource "aws_security_group" "application_sg" {
  vpc_id = aws_vpc.network.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

# CloudWatch Log Groups for Application
resource "aws_cloudwatch_log_group" "webapp_logs" {
  name              = "webapp-logs"
  retention_in_days = 14

  tags = {
    Name = "WebApp Application Logs"
  }
}

resource "aws_cloudwatch_log_group" "webapp_system_logs" {
  name              = "webapp-system-logs"
  retention_in_days = 7

  tags = {
    Name = "WebApp System Logs"
  }
}

resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.accessible[0].id
  vpc_security_group_ids = [aws_security_group.application_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Add user data to configure environment
  user_data = <<-EOF
    #!/bin/bash
    # Create application directory if it doesn't exist
    mkdir -p /opt/myapp
    
    # Create environment file
    cat > /opt/myapp/.env << ENVEOF
    DB_HOST=${aws_db_instance.webapp_db.address}
    DB_PORT=${var.db_port}
    DB_USER=${var.db_username}
    DB_PASSWORD=${var.db_password}
    DB_NAME=${var.db_name}
    AWS_REGION=${var.region}
    S3_BUCKET=${aws_s3_bucket.webapp_bucket.bucket}
    PORT=${var.app_port}
    NODE_ENV=production
    ENVEOF
    
    # Set proper permissions
    chmod 600 /opt/myapp/.env
    chown webapp:webapp /opt/myapp/.env
    
    # Create log directory if it doesn't exist
    mkdir -p /var/log/webapp
    chown webapp:webapp /var/log/webapp
    chmod 755 /var/log/webapp

    # Configure CloudWatch agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWAGENTCONFIG'
    {
      "agent": {
        "metrics_collection_interval": 10,
        "run_as_user": "webapp"
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/webapp/application.log",
                "log_group_name": "webapp-logs",
                "log_stream_name": "{instance_id}-application",
                "retention_in_days": 14
              },
              {
                "file_path": "/var/log/syslog",
                "log_group_name": "webapp-system-logs",
                "log_stream_name": "{instance_id}-syslog",
                "retention_in_days": 7
              }
            ]
          }
        }
      },
      "metrics": {
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

    # Restart CloudWatch agent to apply new configuration
    systemctl restart amazon-cloudwatch-agent
    
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
  bucket = "csye6225-${random_uuid.bucket_uuid.result}"

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
  bucket = aws_s3_bucket.webapp_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "webapp_bucket_lifecycle" {
  bucket = aws_s3_bucket.webapp_bucket.bucket

  rule {
    id     = "transition-to-standard-ia"
    status = "Enabled"

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
  /*lifecycle {
    ignore_changes = [tags]
  }*/
}

# DB Parameter Group
resource "aws_db_parameter_group" "db_parameter_group" {
  name   = "csye6225-db-param-group"
  family = "mysql8.0"

  tags = {
    Name = "WebApp DB Parameter Group"
  }
  /*lifecycle {
    ignore_changes = [tags]
  }*/
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

  /*tags = {
    Name = "WebApp RDS Instance"
  }*/
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

# CloudWatch IAM Policy
resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "cloudwatch_access_policy"
  description = "Policy allowing EC2 to publish logs and metrics to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Attach CloudWatch Policy to EC2 Role
resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_s3_profile"
  role = aws_iam_role.ec2_s3_access.name
}

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_alarm" {
  alarm_name          = "webapp-high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors EC2 CPU utilization"
  
  dimensions = {
    InstanceId = aws_instance.web.id
  }
}

# Custom Metric Dashboard for Application Metrics
resource "aws_cloudwatch_dashboard" "webapp_dashboard" {
  dashboard_name = "webapp-metrics-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web.id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["CWAgent", "webapp_api.get./.count", { "stat": "Sum" }],
            ["CWAgent", "webapp_api.post./.count", { "stat": "Sum" }],
            ["CWAgent", "webapp_api.delete./.count", { "stat": "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "API Call Counts"
        }
      }
    ]
  })
}