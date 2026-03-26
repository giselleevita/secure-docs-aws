resource "aws_s3_bucket" "config_logs" {
  bucket = "secure-docs-aws-config-logs-${data.aws_region.current.name}"
}

resource "aws_s3_bucket_public_access_block" "config_logs" {
  bucket                  = aws_s3_bucket.config_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "config_role" {
  name = "secure-docs-aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config_service" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_config_configuration_recorder" "secure_docs" {
  name     = "secure-docs-aws-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "secure_docs" {
  name           = "secure-docs-aws-channel"
  s3_bucket_name = aws_s3_bucket.config_logs.bucket

  depends_on = [aws_config_configuration_recorder.secure_docs]
}

resource "aws_config_configuration_recorder_status" "secure_docs" {
  name       = aws_config_configuration_recorder.secure_docs.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.secure_docs]
}
