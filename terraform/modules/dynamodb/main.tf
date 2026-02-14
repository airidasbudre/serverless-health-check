resource "aws_dynamodb_table" "requests" {
  name         = "${var.environment}-requests-db"
  billing_mode = var.billing_mode
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Server-side encryption with customer-managed KMS key
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # Point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = true
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-requests-db"
      Environment = var.environment
    }
  )
}
