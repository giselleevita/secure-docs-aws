data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  cloudtrail_arn = "arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/secure-docs-trail"
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:GetBucketAcl"]

    resources = [module.storage.bucket_arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.cloudtrail_arn]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = ["${module.storage.bucket_arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.cloudtrail_arn]
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_kms" {
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = ["kms:*"]

    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudTrailEncryptLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "kms:DescribeKey",
      "kms:GenerateDataKey*"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.cloudtrail_arn]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = module.storage.bucket_name
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

resource "aws_kms_key_policy" "cloudtrail" {
  key_id = module.storage.kms_key_id
  policy = data.aws_iam_policy_document.cloudtrail_kms.json
}

resource "aws_cloudtrail" "secure_docs" {
  name                          = "secure-docs-trail"
  s3_bucket_name                = module.storage.bucket_name
  enable_log_file_validation    = true
  include_global_service_events = true
  is_multi_region_trail         = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.trail.arn

  depends_on = [
    aws_kms_key_policy.cloudtrail,
    aws_s3_bucket_policy.cloudtrail
  ]
}

resource "aws_cloudwatch_log_group" "trail" {
  name              = "secure-docs-trail"
  retention_in_days = 365
}

resource "aws_iam_role" "trail" {
  name = "secure-docs-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "trail" {
  name = "secure-docs-cloudtrail-policy"
  role = aws_iam_role.trail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
      }
    ]
  })
}