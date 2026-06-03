# V3 Production Layer — AWS WAF for API Gateway

# WAFv2 IP Set for rate limiting (optional: for allowlisting trusted IPs)
resource "aws_wafv2_ip_set" "trusted_ips" {
  name               = "secure-docs-trusted-ips"
  description        = "Trusted IPs for rate limit exemption"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = [] # Empty; can be populated later

  tags = {
    Name = "secure-docs-trusted-ips"
  }
}

# WAFv2 Web ACL for API Gateway
resource "aws_wafv2_web_acl" "api_gateway" {
  name        = "secure-docs-api-waf"
  description = "WAF rules for SecureDocs API Gateway"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: AWS Managed Rules — Core Rule Set (CRS)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    action {
      block {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclusions for false positives (adjust as needed)
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules — SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 1

    action {
      block {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSetMetrics"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Rate Limiting (4000 requests per 5 minutes per IP)
  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate_limit_response"
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = 4000
        aggregate_key_type = "IP"

        # Scope down to API paths for better rate limiting
        scope_down_statement {
          byte_match_statement {
            search_string = "/api/"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
            positional_constraint = "STARTS_WITH"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetrics"
      sampled_requests_enabled   = true
    }
  }

  # Custom response body for rate limiting
  custom_response_body {
    key          = "rate_limit_response"
    content      = "Rate limit exceeded. Please retry after some time."
    content_type = "TEXT_PLAIN"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "secure-docs-api-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "secure-docs-api-waf"
  }
}

# Associate WAF ACL with API Gateway
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = aws_apigatewayv2_api.this.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway.arn
}

# CloudWatch Log Group for WAF metrics and logs
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/wafv2/secure-docs-api"
  retention_in_days = 14

  tags = {
    Name = "secure-docs-waf-logs"
  }
}

# WAF Log Configuration
resource "aws_wafv2_web_acl_logging_configuration" "api_gateway" {
  resource_arn            = aws_wafv2_web_acl.api_gateway.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]

  depends_on = [aws_cloudwatch_log_group.waf_logs]
}
