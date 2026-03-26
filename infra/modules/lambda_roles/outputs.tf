output "upload_role_arn" {
  value = aws_iam_role.lambda_upload.arn
}

output "read_role_arn" {
  value = aws_iam_role.lambda_read.arn
}

output "delete_role_arn" {
  value = aws_iam_role.lambda_delete.arn
}
