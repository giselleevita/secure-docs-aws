resource "aws_dynamodb_table" "users" {
  name         = "secure-docs-users-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "owner_id"
  range_key    = "object_key"

  attribute {
    name = "owner_id"
    type = "S"
  }

  attribute {
    name = "object_key"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Project     = "secure-docs"
    Environment = var.environment
  }
}

output "table_name" {
  value = aws_dynamodb_table.users.name
}

output "table_arn" {
  value = aws_dynamodb_table.users.arn
}
