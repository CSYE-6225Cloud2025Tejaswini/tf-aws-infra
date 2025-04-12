# KMS keys for resource encryption
data "aws_caller_identity" "current" {}
resource "aws_kms_key" "ec2_key" {
  description             = "KMS key for EC2 encryption"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags = {
    Name = "ec2-kms"
  }
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "Allow Autoscaling Service",
        Effect = "Allow",
        Principal = {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:*"
        ],
        Resource = "*"
      },
      {
        Sid       = "Allow EC2 Role Access"
        Effect    = "Allow"
        Principal = { "AWS" : aws_iam_role.ec2_s3_access.arn }
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Auto Scaling and EC2 Services"
        Effect = "Allow"
        Principal = {
          "Service" : [
            "autoscaling.amazonaws.com",
            "ec2.amazonaws.com"
          ]
        }
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo"
        ]
        Resource = "*"
      }
    ]
  })
}
resource "aws_kms_key" "rds_key" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  tags = {
    Name = "RDS-KMS-Key"
  }
}

resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  tags = {
    Name = "S3-KMS-Key"
  }
}

resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 10
  enable_key_rotation     = true


  tags = {
    Name = "Secrets-KMS-Key"
  }
}

# KMS Aliases for easier reference
resource "aws_kms_alias" "ec2_key_alias" {
  name          = "alias/ec2-encryption-key"
  target_key_id = aws_kms_key.ec2_key.key_id
}

resource "aws_kms_alias" "rds_key_alias" {
  name          = "alias/rds-encryption-key"
  target_key_id = aws_kms_key.rds_key.key_id
}

resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/s3-encryption-key"
  target_key_id = aws_kms_key.s3_key.key_id
}

resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/secrets-encryption-key"
  target_key_id = aws_kms_key.secrets_key.key_id
}