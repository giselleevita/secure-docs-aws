# V3 Production Layer — VPC Endpoints for AWS Services

# VPC Endpoint for S3 (Gateway endpoint)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.secure_docs.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name = "secure-docs-s3-endpoint"
  }
}

# S3 Endpoint Policy — allow access to SecureDocs bucket only
resource "aws_vpc_endpoint_policy" "s3" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion"
        ]
        Resource = [
          module.storage.bucket_arn,
          "${module.storage.bucket_arn}/*"
        ]
      }
    ]
  })
}

# VPC Endpoint for DynamoDB (Gateway endpoint)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.secure_docs.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name = "secure-docs-dynamodb-endpoint"
  }
}

# DynamoDB Endpoint Policy — allow access to SecureDocs table only
resource "aws_vpc_endpoint_policy" "dynamodb" {
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = module.dynamodb.table_arn
      }
    ]
  })
}

# VPC Endpoint for KMS (Interface endpoint)
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.secure_docs.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.endpoints.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "secure-docs-kms-endpoint"
  }
}

# VPC Endpoint for CloudWatch Logs (Interface endpoint)
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.secure_docs.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.endpoints.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "secure-docs-logs-endpoint"
  }
}

# VPC Endpoint for STS (Interface endpoint)
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.secure_docs.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.endpoints.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "secure-docs-sts-endpoint"
  }
}

# VPC Endpoint for Secrets Manager (Interface endpoint) — for reading secrets
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.secure_docs.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.endpoints.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = {
    Name = "secure-docs-secretsmanager-endpoint"
  }
}
