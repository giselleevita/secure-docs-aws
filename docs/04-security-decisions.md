## ADR-001: Private S3 Bucket with KMS

- Chose: S3 bucket private by default, KMS CMK with rotation, server-side encryption using KMS, versioning enabled
- Why: Defense-in-depth. Even if S3 policy drifts, the bucket is not public and data is encrypted.
- Risk reduced: Accidental public exposure, unencrypted data at rest, no versioning for accident recovery
- Weakness remaining: No explicit S3 bucket policy yet (no Allow/Deny rules), no automatic remediation for misconfiguration
