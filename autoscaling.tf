resource "aws_launch_template" "webapp_launch_template" {
  name          = "csye6225_asg"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.existing_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.application_sg.id]
  }

  user_data = base64encode(<<EOF
#!/bin/bash
set -e

# Environment values
ENVIRONMENT="${var.environment}"
AWS_REGION="${var.region}"
S3_BUCKET="${aws_s3_bucket.webapp_bucket.bucket}"

# Install basic packages
apt-get update -y
apt-get install -y curl unzip jq

# Install AWS CLI v2 manually
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Setup application directory
mkdir -p /opt/webapp
mkdir -p /opt/webapp/logs
chmod 755 /opt/webapp/logs

# Fetch secrets from Secrets Manager
SECRET_JSON=\$(aws secretsmanager get-secret-value \
  --secret-id db-password-$${ENVIRONMENT} \
  --region $${AWS_REGION} \
  --query SecretString \
  --output text)

DB_HOST=\$(echo $${SECRET_JSON} | jq -r '.host')
DB_PORT=\$(echo $${SECRET_JSON} | jq -r '.port')
DB_USER=\$(echo $${SECRET_JSON} | jq -r '.username')
DB_PASSWORD=\$(echo $${SECRET_JSON} | jq -r '.password')
DB_NAME=\$(echo $${SECRET_JSON} | jq -r '.dbname')

# Create .env file
cat > /opt/webapp/.env <<EOL
DB_HOST=$${DB_HOST}
DB_PORT=$${DB_PORT}
DB_USER=$${DB_USER}
DB_PASSWORD=$${DB_PASSWORD}
DB_NAME=$${DB_NAME}
AWS_REGION=$${AWS_REGION}
S3_BUCKET=$${S3_BUCKET}
PORT=8080
NODE_ENV=production
LOG_DIRECTORY=/opt/webapp/logs
AWS_CLOUDWATCH_ENABLED=true
CLOUDWATCH_LOG_GROUP=webapp-logs
EOL

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c default

# Start the web application
systemctl daemon-reload
systemctl enable webapp
systemctl start webapp

echo "Application setup complete!"
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "WebApp-ASG-Instance"
    }
  }

  tags = {
    Name = "WebApp-Launch-Template"
  }
}


# Auto Scaling Group
resource "aws_autoscaling_group" "webapp_asg" {
  name                      = "webapp-asg"
  max_size                  = 5
  min_size                  = 3
  desired_capacity          = 3
  health_check_type         = "ELB"
  health_check_grace_period = 300
  vpc_zone_identifier       = aws_subnet.accessible[*].id
  target_group_arns         = [aws_lb_target_group.webapp_tg.arn]

  launch_template {
    id      = aws_launch_template.webapp_launch_template.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 90
      instance_warmup        = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "WebApp-ASG-Instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Application"
    value               = "WebApp"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_secretsmanager_secret.db_password_secret]
}

# Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Scale up when CPU exceeds 5%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "low-cpu-usage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 3
  alarm_description   = "Scale down when CPU is below 3%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}
