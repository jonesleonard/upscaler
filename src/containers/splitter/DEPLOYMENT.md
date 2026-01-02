# Splitter Container Deployment Guide

This document describes how the splitter container is automatically built, scanned, and deployed using GitHub Actions.

## Overview

The splitter container splits video files into segments for parallel processing. It's automatically deployed to AWS Batch when changes are pushed to the `main` branch.

## Workflow: `.github/workflows/container-splitter-deploy.yml`

### Triggers

- **Push to `main`**: Builds, scans, and deploys to dev environment
- **Pull Request**: Builds and scans only (no deployment)
- **Manual Dispatch**: Deploy to specific environment (dev/staging/prod)

### Pipeline Stages

```
┌─────────────┐
│   Build &   │
│    Scan     │──────┐
└─────────────┘      │
                     │
                     ▼
              ┌─────────────┐
              │  Push to    │
              │     ECR     │──────┐
              └─────────────┘      │
                                   │
                                   ▼
                            ┌─────────────┐
                            │   Update    │
                            │ Batch Job   │
                            └─────────────┘
                                   │
                                   ▼
                            ┌─────────────┐
                            │  Optional   │
                            │  Test Job   │
                            └─────────────┘
```

## Stage Details

### 1. Build & Scan Container

**What it does:**

- Builds Docker image with metadata (version, SHA, build date)
- Runs Trivy vulnerability scanner
- Fails on CRITICAL or HIGH vulnerabilities
- Uploads scan results to GitHub Security tab
- Saves image artifact for push stage

**Key Features:**

- Multi-platform build support (amd64)
- Build cache optimization using GitHub Actions cache
- OCI image labels for traceability
- SARIF format for security integration

**Security Checks:**

- Vulnerability scanning (Trivy)
- Container security best practices
- Dependency analysis
- OS package vulnerabilities

### 2. Push to ECR (Dev)

**What it does:**

- Authenticates to AWS using OIDC (no long-lived credentials)
- Logs into Amazon ECR
- Tags image with multiple identifiers:
  - Full SHA: `abc123def456...`
  - Short SHA: `abc123d`
  - `latest` (for dev environment)
- Pushes all tags to ECR
- Triggers ECR image scanning

**Environment Variables:**

- `AWS_ROLE_ARN`: IAM role for deployment (from secrets)
- `AWS_REGION`: AWS region (from vars or default)
- `PROJECT_NAME`: Project prefix (from vars)

### 3. Update Batch Job Definition

**What it does:**

- Retrieves current active job definition
- Updates container image URI to new version
- Registers new job definition revision
- Maintains all other job configuration (resources, environment)

**Important Notes:**

- Does NOT modify existing running jobs
- New jobs automatically use the latest revision
- Preserves resource allocations and IAM roles
- Fails if no job definition exists (Terraform must create it first)

### 4. Integration Test (Optional)

**What it does:**

- Uploads test video to S3
- Submits test Batch job
- Monitors job completion
- Verifies segments and manifest creation

**Enable by setting:**

```
Repository Variables → RUN_INTEGRATION_TESTS = true
```

## Required Secrets and Variables

### Secrets (Repository Settings → Secrets)

| Name | Description | Example |
|------|-------------|---------|
| `AWS_ROLE_ARN` | IAM role ARN for OIDC | `arn:aws:iam::123456789012:role/GitHubActionsRole` |
| `TF_STATE_BUCKET` | S3 bucket for Terraform state | `my-terraform-state-bucket` |

### Variables (Repository Settings → Variables)

| Name | Description | Default |
|------|-------------|---------|
| `AWS_REGION` | AWS region | `us-east-1` |
| `PROJECT_NAME` | Project prefix | `upscaler` |
| `RUN_INTEGRATION_TESTS` | Enable integration tests | `false` |

### Environment Secrets (Settings → Environments → dev)

Create a `dev` environment with:

- **Required reviewers**: (optional) Team members who must approve
- **Deployment branches**: `main` only
- **Environment secrets**: Same as repository secrets if different per env

## Manual Deployment

To manually deploy to a specific environment:

1. Go to **Actions** tab
2. Select **Build and Deploy Splitter Container**
3. Click **Run workflow**
4. Select environment (dev/staging/prod)
5. Click **Run workflow**

## Monitoring Deployment

### GitHub Actions

1. Go to **Actions** tab
2. Click on workflow run
3. View logs for each job
4. Check **Security** tab for vulnerability scan results

### AWS Console

1. **ECR**: View pushed images and scan results
   - Console → ECR → Repositories → `{PROJECT_NAME}-splitter-{env}-ecr`

2. **Batch**: View job definition revisions
   - Console → Batch → Job definitions → `{PROJECT_NAME}-splitter-job-{env}`

3. **CloudWatch**: View job execution logs
   - Console → CloudWatch → Log groups → `/aws/batch/job`

## Troubleshooting

### Build Fails with Vulnerability Scan

**Problem**: Trivy finds CRITICAL or HIGH vulnerabilities

**Solution**:

1. Check Security tab for details
2. Update base image or dependencies
3. Review Dockerfile for security best practices

### ECR Push Fails

**Problem**: Authentication or permission errors

**Solution**:

1. Verify `AWS_ROLE_ARN` is correct
2. Check IAM role trust policy allows GitHub OIDC
3. Verify ECR repository exists (created by Terraform)
4. Check IAM role has `ecr:PutImage` permission

### Job Definition Update Fails

**Problem**: "No active job definition found"

**Solution**:

1. Run Terraform apply first to create initial job definition
2. Verify Batch module is deployed
3. Check job definition name matches: `{PROJECT_NAME}-splitter-job-{env}`

### Image Not Used by New Jobs

**Problem**: New jobs still use old image

**Solution**:

1. Verify job definition revision was incremented
2. Check Batch console for latest revision number
3. Ensure new jobs reference the updated job definition
4. Old running jobs won't be affected (by design)

## Rollback Procedure

If a deployed container has issues:

### Option 1: Revert Code and Redeploy

```bash
git revert <commit-sha>
git push origin main
# Workflow runs automatically
```

### Option 2: Manual ECR Tag Update

```bash
# Point 'latest' tag to previous good image
aws ecr batch-get-image \
  --repository-name upscaler-splitter-dev-ecr \
  --image-ids imageTag=<previous-sha> \
  --query 'images[].imageManifest' \
  --output text | \
aws ecr put-image \
  --repository-name upscaler-splitter-dev-ecr \
  --image-tag latest \
  --image-manifest stdin
```

### Option 3: Register Previous Job Definition

```bash
# Get previous revision
aws batch describe-job-definitions \
  --job-definition-name upscaler-splitter-job-dev \
  --status INACTIVE \
  --query 'jobDefinitions[0]' > prev-job-def.json

# Re-register it
aws batch register-job-definition \
  --cli-input-json file://prev-job-def.json
```

## Security Best Practices

✅ **Implemented:**

- OIDC authentication (no long-lived AWS credentials)
- Read-only default permissions
- Vulnerability scanning on every build
- Image scanning in ECR
- Non-root container user
- Minimal base image (python:3.11-slim)

⚠️ **Additional Recommendations:**

- Enable ECR image signing (AWS Signer or Cosign)
- Set up AWS GuardDuty for runtime monitoring
- Use AWS Secrets Manager for sensitive environment variables
- Implement network policies in VPC
- Enable CloudTrail for API audit logging

## Cost Optimization

- **Build caching**: Reduces build time by ~50%
- **Layer optimization**: Minimizes image size
- **ECR lifecycle policy**: Auto-deletes old images (configured in Terraform)
- **Artifact retention**: Build artifacts expire after 1 day

## Next Steps

1. **Set up OIDC**: Configure AWS IAM role with GitHub OIDC trust
2. **Configure secrets**: Add `AWS_ROLE_ARN` and other secrets
3. **Initial Terraform deploy**: Create ECR and Batch resources
4. **Test pipeline**: Make a small change and push to trigger workflow
5. **Enable integration tests**: Set `RUN_INTEGRATION_TESTS` variable
6. **Add staging/prod**: Extend workflow for additional environments

## Related Documentation

- [GitHub Actions Best Practices](../../.github/instructions/github-actions-ci-cd-best-practices.instructions.md)
- [Docker Best Practices](../../.github/instructions/containerization-docker-best-practices.instructions.md)
- [Terraform Deployment](./../terraform/README.md)
- [AWS Batch Documentation](https://docs.aws.amazon.com/batch/)

## Support

For issues or questions:

1. Check workflow logs in GitHub Actions
2. Review CloudWatch logs for runtime errors
3. Open an issue in the repository
4. Contact the DevOps team
