data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  dynamodb_table_arn = "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.users_table_name}"

  lambda_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_upload" {
  name               = "lambda-upload-${var.environment}"
  assume_role_policy = local.lambda_assume_role_policy
}

resource "aws_iam_role_policy" "lambda_upload" {
  name = "lambda-upload-policy"
  role = aws_iam_role.lambda_upload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectVersion"]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = local.dynamodb_table_arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role" "lambda_read" {
  name               = "lambda-read-${var.environment}"
  assume_role_policy = local.lambda_assume_role_policy
}

resource "aws_iam_role_policy" "lambda_read" {
  name = "lambda-read-policy"
  role = aws_iam_role.lambda_read.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query"]
        Resource = local.dynamodb_table_arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role" "lambda_delete" {
  name               = "lambda-delete-${var.environment}"
  assume_role_policy = local.lambda_assume_role_policy
}

resource "aws_iam_role_policy" "lambda_delete" {
  name = "lambda-delete-policy"
  role = aws_iam_role.lambda_delete.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:DeleteObject", "s3:DeleteObjectVersion"]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:DeleteItem"]
        Resource = local.dynamodb_table_arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.kms_key_arn
      }
    ]
  })
}
