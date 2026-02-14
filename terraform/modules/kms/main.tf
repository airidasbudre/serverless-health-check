data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for ${var.environment} DynamoDB table encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda to use the key"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB to use the key"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "dynamodb.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-dynamodb-kms-key"
    }
  )
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${var.environment}-dynamodb-key"
  target_key_id = aws_kms_key.dynamodb.key_id
}
