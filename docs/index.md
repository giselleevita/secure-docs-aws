# SecureDocs AWS Documentation Index

Welcome to the SecureDocs AWS learning project documentation.
This repo demonstrates a secure, JWT-based SaaS workflow on AWS and is intended to be safe, public, and easy to audit.

## Architecture

- [Overview](./architecture/overview.md) - high-level system flow and components.
- [Project Overview](./architecture/project-overview.md) - context, goals, and key services used.
- [Architecture Decisions](./architecture/decisions.md) - why key patterns were chosen.

## Security

- [Threat Model](./security/threat-model.md) - assets, trust boundaries, and threat scenarios.
- [Security Decisions](./security/security-decisions.md) - IAM, authentication, and authorization choices.
- [Validation Results](./security/validation-results.md) - security control outcomes and test evidence.

## Verification / Validation

- [V1/V2 Verification](./verification/verify-v1-v2.md) - core test plan and behavior checks.
- [V3 Verification](./verification/verify-v3.md) - production-ready verification plan.
- [Test Plan](./verification/test-plan.md) - overall test strategy and tooling.

## Operations

- [Runbooks](./operations/runbooks.md) - common operational procedures and failure-recovery steps.

## Notes

- [AWS Concepts](./notes/aws-concepts.md) - glossary-style notes for AWS building blocks.
- [IAM Mistakes](./notes/iam-mistakes.md) - common pitfalls and how they were avoided here.
