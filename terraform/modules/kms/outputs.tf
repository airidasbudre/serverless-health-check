output "key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.dynamodb.key_id
}

output "key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.dynamodb.arn
}

output "key_alias" {
  description = "Alias of the KMS key"
  value       = aws_kms_alias.dynamodb.name
}
