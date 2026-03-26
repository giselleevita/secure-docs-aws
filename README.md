# SecureDocs AWS

_A security-focused document storage service on AWS that teaches IAM, S3, KMS, CloudTrail, and ownership-enforcement patterns._

## Overview

SecureDocs AWS is a serverless document service where authenticated users can upload, list, download, and delete only their own files. The project is deliberately small, but it exercises the core security controls that matter in a multi-user cloud system.

It exists as a hands-on learning system rather than a production-ready product. The goal is to make identity, authorization, storage security, least-privilege access, and auditability concrete through a working AWS design.

## Architecture

A user authenticates with Cognito and sends a JWT-backed request through HTTP API Gateway. API Gateway validates the token, passes the request to Lambda, and Lambda uses the authenticated identity as the owner boundary for the operation.

DynamoDB stores file metadata keyed by owner_id and object_key, which lets the application verify ownership before returning access to data. S3 stores the actual files in a private bucket with block public access enabled, server-side encryption with KMS, and versioning turned on.

Access is split across dedicated IAM roles for upload, read, and delete operations, so each Lambda function has only the permissions it needs. Clients receive short-lived presigned URLs instead of direct S3 credentials, and CloudTrail plus CloudWatch Logs provide the audit trail for API and storage activity.

## Security-Specific Features

- Identity and authorization are handled through Cognito and JWT validation in API Gateway.
- Ownership is enforced in the application layer through owner_id checks against DynamoDB before file access is granted.
- S3 is private by default, blocks public access, uses SSE-KMS, and has versioning enabled.
- IAM permissions are split by Lambda function so upload, read, and delete paths do not share a broad role.
- Presigned URLs are short-lived at 5 minutes and no direct S3 keys are exposed to clients.
- CloudTrail and CloudWatch Logs provide audit visibility across API, Lambda, and storage activity.
- The repository includes a testable threat model and documented security decisions in [docs/04-security-decisions.md](docs/04-security-decisions.md).

## How to Run

Configure AWS credentials with aws configure, then initialize and apply the Terraform configuration using terraform init and terraform apply. The configuration lives under infra/environments/dev.

- Prerequisites: AWS CLI and Terraform

After apply, the API endpoint is shown in Terraform output.

## Why This Exists

SecureDocs AWS is a learning system, not a product. It is designed to teach cloud-security-relevant concepts by forcing the system to answer practical questions about who a request belongs to, whether that user is authorized, how data is protected at rest, and how actions are audited.

That makes it useful for people working in cloud security, DevSecOps, and backend engineering who want a concrete example of IAM design, S3 protection, KMS-backed encryption, presigned access patterns, and threat-model-driven implementation.

## What's Next

Natural next steps include extending the control set with AWS Config and Lambda-based remediation, GuardDuty and Security Hub integration, rate limiting, and stronger data loss prevention patterns.

This is a roadmap, not a checkbox.

## License / Credits

Licensed under the MIT License.
