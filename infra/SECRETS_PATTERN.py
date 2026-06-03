# Python Lambda Handler — Secrets Manager Integration Pattern
# 
# This snippet demonstrates how to read a secret from AWS Secrets Manager
# without storing credentials in code or environment files.
# 
# Usage: Place the secret ARN in a Lambda environment variable, then call
# get_secret() at the beginning of your handler.
#
# Example Lambda deployment with secret ARN:
#   environment {
#     variables = {
#       SECRET_ARN = aws_secretsmanager_secret.example.arn
#     }
#   }

import json
import os
import boto3

secrets_client = boto3.client("secretsmanager")

def get_secret(secret_arn: str) -> dict:
    """
    Retrieve a secret from AWS Secrets Manager using its ARN.
    
    Args:
        secret_arn: ARN of the secret to retrieve
        
    Returns:
        dict: Parsed secret value (assumes JSON format)
    """
    try:
        response = secrets_client.get_secret_value(SecretId=secret_arn)
        secret_value = json.loads(response["SecretString"])
        return secret_value
    except Exception as e:
        print(f"Error retrieving secret: {e}")
        raise


def handler(event, context):
    """
    Lambda handler that reads a database password from Secrets Manager.
    """
    # Get the secret ARN from environment variable
    secret_arn = os.environ.get("DB_SECRET_ARN")
    
    # Retrieve the secret (API key, database password, etc.)
    secret = get_secret(secret_arn)
    
    # Extract specific key from secret
    db_password = secret.get("password")
    
    # Use the secret in your business logic
    # DO NOT log or print the secret value
    
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Secret retrieved successfully"})
    }


# ─────────────────────────────────────────────────────────────────────────────
# Corresponding Terraform Definitions:
# 
# # Create a secret in AWS Secrets Manager
# resource "aws_secretsmanager_secret" "db_password" {
#   name                    = "secure-docs/db-password"
#   description             = "Database password for SecureDocs"
#   recovery_window_in_days = 7
# }
# 
# # Store the actual secret value
# resource "aws_secretsmanager_secret_version" "db_password" {
#   secret_id = aws_secretsmanager_secret.db_password.id
#   secret_string = jsonencode({
#     password = var.db_password  # Injected via terraform apply -var or .tfvars
#     username = "dbuser"
#   })
# }
# 
# # Add permission to Lambda IAM role to read this secret
# resource "aws_iam_role_policy" "lambda_secrets_access" {
#   name   = "lambda-secrets-access"
#   role   = module.lambda_roles.upload_role_arn
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:GetSecretValue"
#         ]
#         Resource = aws_secretsmanager_secret.db_password.arn
#       }
#     ]
#   })
# }
# 
# # Lambda function with secret ARN in environment
# resource "aws_lambda_function" "example" {
#   function_name = "lambda-example"
#   runtime       = "python3.12"
#   handler       = "lambda_function.handler"
#   role          = module.lambda_roles.upload_role_arn
#   filename      = "lambda_function.zip"
#   
#   environment {
#     variables = {
#       SECRET_ARN = aws_secretsmanager_secret.db_password.arn
#     }
#   }
# }
