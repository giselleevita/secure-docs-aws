resource "aws_guardduty_detector" "secure_docs" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
  }
}
