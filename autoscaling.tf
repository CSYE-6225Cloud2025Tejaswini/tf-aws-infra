# Launch Template for Auto Scaling Group
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

  user_data = base64encode(<<-EOF
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
    AWS_CLOUDWATCH_ENABLED=true
    CLOUDWATCH_LOG_GROUP=webapp-logs
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
  name_prefix               = "webapp-asg-"
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

  depends_on = [aws_db_instance.webapp_db]
}

# Scale Up Policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
}

# Scale Down Policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
}

# CloudWatch Alarm for High CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "Scale up when CPU exceeds 90%"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}

# CloudWatch Alarm for Low CPU
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "low-cpu-usage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 3
  alarm_description   = "Scale down when CPU is below 30%"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}