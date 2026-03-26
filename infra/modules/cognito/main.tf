resource "aws_cognito_user_pool" "this" {
  name                     = "secure-docs-dev-user-pool"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "this" {
  name         = "secure-docs-dev-app-client"
  user_pool_id = aws_cognito_user_pool.this.id

  explicit_auth_flows = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
}

output "user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.this.arn
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.this.id
}
