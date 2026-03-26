resource "aws_apigatewayv2_api" "this" {
  name          = "secure-docs-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  name             = "cognito-authorizer"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [module.cognito.user_pool_client_id]
    issuer   = "https://cognito-idp.eu-north-1.amazonaws.com/${module.cognito.user_pool_id}"
  }
}

resource "aws_apigatewayv2_integration" "upload_presigned" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload_presigned.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "list_files" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.list_files.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "download_file" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.download_file.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "delete_file" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.delete_file.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_presigned" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "POST /upload-presigned"
  target             = "integrations/${aws_apigatewayv2_integration.upload_presigned.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "list_files" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /list"
  target             = "integrations/${aws_apigatewayv2_integration.list_files.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "download_file" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /download/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.download_file.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "delete_file" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "DELETE /delete/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.delete_file.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_lambda_permission" "upload_presigned" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_presigned.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "list_files" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_files.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "download_file" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.download_file.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "delete_file" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_file.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

output "api_endpoint_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
