data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.root}/../../../app/lambda_function.py"
  output_path = "${path.root}/../../../app/lambda_function.zip"
}

resource "aws_lambda_function" "upload_presigned" {
  function_name    = "lambda-upload-presigned"
  runtime          = "python3.12"
  handler          = "lambda_function.handler"
  role             = module.lambda_roles.upload_role_arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = module.storage.bucket_name
      TABLE_NAME  = module.dynamodb.table_name
      KMS_KEY_ARN = module.storage.kms_key_arn
    }
  }
}

resource "aws_lambda_function" "list_files" {
  function_name    = "lambda-list-files"
  runtime          = "python3.12"
  handler          = "lambda_function.handler"
  role             = module.lambda_roles.read_role_arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = module.storage.bucket_name
      TABLE_NAME  = module.dynamodb.table_name
      KMS_KEY_ARN = module.storage.kms_key_arn
    }
  }
}

resource "aws_lambda_function" "download_file" {
  function_name    = "lambda-download-file"
  runtime          = "python3.12"
  handler          = "lambda_function.handler"
  role             = module.lambda_roles.read_role_arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = module.storage.bucket_name
      TABLE_NAME  = module.dynamodb.table_name
      KMS_KEY_ARN = module.storage.kms_key_arn
    }
  }
}

resource "aws_lambda_function" "delete_file" {
  function_name    = "lambda-delete-file"
  runtime          = "python3.12"
  handler          = "lambda_function.handler"
  role             = module.lambda_roles.delete_role_arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = module.storage.bucket_name
      TABLE_NAME  = module.dynamodb.table_name
      KMS_KEY_ARN = module.storage.kms_key_arn
    }
  }
}
