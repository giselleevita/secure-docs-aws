resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "secure-docs-aws-cloudtrail-logs-${data.aws_region.current.name}"
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_cloudwatch_log_group" "secure_docs_cloudtrail" {
  name              = "/aws/cloudtrail/secure-docs-aws"
  retention_in_days = 365
}

resource "aws_cloudtrail" "secure_docs" {
  name                          = "secure-docs-aws-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_public_access_block.cloudtrail_logs]
}

data "aws_region" "current" {}
