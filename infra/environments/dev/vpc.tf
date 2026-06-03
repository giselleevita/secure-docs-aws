# V3 Production Layer — VPC and Lambda Private Networking

# VPC for Lambda functions and private API execution
resource "aws_vpc" "secure_docs" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "secure-docs-vpc"
    Environment = "dev"
  }
}

# Private Subnet 1 — for Lambda functions
resource "aws_subnet" "lambda_1" {
  vpc_id                  = aws_vpc.secure_docs.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "secure-docs-lambda-subnet-1"
  }
}

# Private Subnet 2 — for Lambda functions (HA)
resource "aws_subnet" "lambda_2" {
  vpc_id                  = aws_vpc.secure_docs.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "secure-docs-lambda-subnet-2"
  }
}

# Private Subnet 3 — for VPC endpoints
resource "aws_subnet" "endpoints" {
  vpc_id                  = aws_vpc.secure_docs.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "secure-docs-endpoints-subnet"
  }
}

# Fetch available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group — Lambda execution context
resource "aws_security_group" "lambda" {
  name        = "secure-docs-lambda-sg"
  description = "Security group for Lambda functions in VPC"
  vpc_id      = aws_vpc.secure_docs.id

  # Egress: Allow HTTPS to AWS services (VPC endpoints and public APIs)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "HTTPS to VPC endpoints"
  }

  # Egress: Allow DNS (UDP 53) to AWS DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "DNS queries within VPC"
  }

  tags = {
    Name = "secure-docs-lambda-sg"
  }
}

# Security Group — VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "secure-docs-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.secure_docs.id

  # Ingress: Allow HTTPS from Lambda security group
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
    description     = "HTTPS from Lambda functions"
  }

  # Ingress: Allow DNS (UDP 53)
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "DNS from VPC"
  }

  tags = {
    Name = "secure-docs-vpc-endpoints-sg"
  }
}

# Route table for private subnets (no internet gateway, only VPC endpoints)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.secure_docs.id

  tags = {
    Name = "secure-docs-private-rt"
  }
}

resource "aws_route_table_association" "lambda_1" {
  subnet_id      = aws_subnet.lambda_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "lambda_2" {
  subnet_id      = aws_subnet.lambda_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "endpoints" {
  subnet_id      = aws_subnet.endpoints.id
  route_table_id = aws_route_table.private.id
}

# VPC Flow Logs for monitoring (published to CloudWatch)
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/secure-docs-flow-logs"
  retention_in_days = 7

  tags = {
    Name = "secure-docs-vpc-flow-logs"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "secure-docs-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "secure-docs-vpc-flow-logs-role"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "secure-docs-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.secure_docs.id

  tags = {
    Name = "secure-docs-vpc-flow-logs"
  }
}
