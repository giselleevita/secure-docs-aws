terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

module "storage" {
  source      = "../../modules/storage"
  environment = "dev"
}

module "cognito" {
  source = "../../modules/cognito"
}

module "dynamodb" {
  source      = "../../modules/dynamodb"
  environment = "dev"
}

module "lambda_roles" {
  source           = "../../modules/lambda_roles"
  environment      = "dev"
  bucket_name      = module.storage.bucket_name
  bucket_arn       = module.storage.bucket_arn
  kms_key_arn      = module.storage.kms_key_arn
  users_table_name = module.dynamodb.table_name
}
