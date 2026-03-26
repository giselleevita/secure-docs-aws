variable "environment" {
  type = string
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "encryption" {
  description             = "SecureDocs encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Project     = "secure-docs"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "encryption" {
  name          = "alias/secure-docs-${var.environment}"
  target_key_id = aws_kms_key.encryption.key_id
}

resource "aws_s3_bucket" "docs" {
  bucket = "secure-docs-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Project     = "secure-docs"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket = aws_s3_bucket.docs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.encryption.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.docs.id
}

output "bucket_arn" {
  value = aws_s3_bucket.docs.arn
}

output "kms_key_arn" {
  value = aws_kms_key.encryption.arn
}

output "kms_key_id" {
  value = aws_kms_key.encryption.key_id
}
