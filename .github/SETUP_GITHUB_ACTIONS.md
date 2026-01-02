# GitHub Actions Setup for Container Deployment

This guide walks you through setting up automated container deployment for the splitter container.

## Prerequisites

- [x] AWS account with appropriate permissions
- [x] GitHub repository with the code
- [x] Terraform infrastructure deployed (ECR, Batch, IAM roles)

## Step-by-Step Setup

### 1. Configure AWS OIDC for GitHub Actions

GitHub Actions can authenticate to AWS without storing long-lived credentials using OpenID Connect (OIDC).

#### Create the OIDC Identity Provider (One-time setup)

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### Create IAM Role for GitHub Actions

Create a file `github-actions-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

Create the role:

```bash
aws iam create-role \
  --role-name GitHubActionsDeployRole \
  --assume-role-policy-document file://github-actions-trust-policy.json
```

#### Attach Necessary Permissions

Create a policy file `github-actions-permissions.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages",
        "ecr:StartImageScan"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "batch:DescribeJobDefinitions",
        "batch:RegisterJobDefinition",
        "batch:DeregisterJobDefinition",
        "batch:SubmitJob",
        "batch:DescribeJobs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::YOUR_ACCOUNT_ID:role/*-ecs-task-execution-role",
        "arn:aws:iam::YOUR_ACCOUNT_ID:role/*-job-*-role"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR_TERRAFORM_STATE_BUCKET/*",
        "arn:aws:s3:::YOUR_PROJECT_BUCKET/*"
      ]
    }
  ]
}
```

Attach the policy:

```bash
aws iam put-role-policy \
  --role-name GitHubActionsDeployRole \
  --policy-name GitHubActionsDeployPolicy \
  --policy-document file://github-actions-permissions.json
```

### 2. Configure GitHub Secrets

Go to your repository: **Settings → Secrets and variables → Actions**

#### Add Repository Secrets

Click **New repository secret** for each:

| Name | Value | Example |
|------|-------|---------|
| `AWS_ROLE_ARN` | ARN of the IAM role created above | `arn:aws:iam::123456789012:role/GitHubActionsDeployRole` |
| `TF_STATE_BUCKET` | S3 bucket for Terraform state | `my-terraform-state-bucket` |

### 3. Configure GitHub Variables

Go to: **Settings → Secrets and variables → Actions → Variables tab**

Click **New repository variable** for each:

| Name | Value | Example |
|------|-------|---------|
| `AWS_REGION` | AWS region for deployment | `us-east-1` |
| `PROJECT_NAME` | Project prefix (must match Terraform) | `upscaler` |
| `RUN_INTEGRATION_TESTS` | Enable integration tests (optional) | `false` |

### 4. Create GitHub Environment (Optional but Recommended)

Go to: **Settings → Environments → New environment**

1. **Environment name**: `dev`
2. **Deployment branches**: Select "Selected branches" → Add `main`
3. **Required reviewers**: Add team members who must approve (optional)
4. **Environment secrets**: Can override repository secrets if different per environment

Repeat for `staging` and `prod` environments if needed.

### 5. Initial Terraform Deployment

Before the GitHub Actions workflow can update Batch job definitions, you must create them first:

```bash
cd src/terraform

# Initialize and apply
terraform init -backend-config=backend-config.tfvars
terraform apply
```

This creates:

- ECR repositories
- Batch compute environments
- Batch job queues
- Initial job definitions
- IAM roles

### 6. Verify Workflow Configuration

The workflow file is already created at:

```
.github/workflows/container-splitter-deploy.yml
```

**Review the workflow:**

- Check that environment names match your setup
- Verify ECR repository names match Terraform outputs
- Confirm job definition names match Terraform

### 7. Test the Workflow

#### Option 1: Push a Change

```bash
cd src/containers/splitter
# Make a small change
echo "# Test deployment" >> Dockerfile
git add .
git commit -m "test: trigger container deployment"
git push origin main
```

#### Option 2: Manual Trigger

1. Go to **Actions** tab
2. Select **Build and Deploy Splitter Container**
3. Click **Run workflow**
4. Select `dev` environment
5. Click **Run workflow**

### 8. Monitor the Deployment

1. **GitHub Actions**: Watch the workflow run in real-time
   - Green checkmarks = success
   - Red X = failure (click for logs)

2. **GitHub Security Tab**: View vulnerability scan results
   - Critical/High vulnerabilities block deployment

3. **AWS ECR**: Verify image was pushed

   ```bash
   aws ecr describe-images \
     --repository-name upscaler-splitter-dev-ecr \
     --region us-east-1
   ```

4. **AWS Batch**: Verify job definition was updated

   ```bash
   aws batch describe-job-definitions \
     --job-definition-name upscaler-splitter-job-dev \
     --status ACTIVE
   ```

### 9. Test the Deployed Container

Submit a test Batch job using the new image:

```bash
aws batch submit-job \
  --job-name test-splitter-$(date +%s) \
  --job-queue upscaler-split-job-queue-dev \
  --job-definition upscaler-splitter-job-dev \
  --container-overrides '{
    "environment": [
      {"name": "INPUT_S3_URI", "value": "s3://YOUR_BUCKET/test-video.mp4"},
      {"name": "OUTPUT_S3_PREFIX", "value": "s3://YOUR_BUCKET/segments/test-123"},
      {"name": "MANIFEST_KEY", "value": "s3://YOUR_BUCKET/segments/test-123/manifest.json"}
    ]
  }'
```

Monitor the job:

```bash
# Get job ID from submit command output
JOB_ID="your-job-id"

# Check status
aws batch describe-jobs --jobs $JOB_ID

# View logs (once running)
aws logs tail /aws/batch/job --follow
```

## Troubleshooting

### OIDC Trust Relationship Error

**Error**: `Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Fix**: Verify the trust policy in IAM role allows your GitHub repository:

```bash
aws iam get-role --role-name GitHubActionsDeployRole
```

Check that `token.actions.githubusercontent.com:sub` matches:

```
repo:YOUR_ORG/YOUR_REPO:*
```

### ECR Repository Not Found

**Error**: `RepositoryNotFoundException`

**Fix**: Run Terraform apply first to create ECR repositories, or verify the repository name matches your `PROJECT_NAME` variable.

### Job Definition Not Found

**Error**: `No active job definition found`

**Fix**:

1. Run Terraform apply to create initial job definition
2. Verify the job definition name matches: `{PROJECT_NAME}-splitter-job-{env}`

### Permission Denied Errors

**Error**: `AccessDenied` or `User is not authorized`

**Fix**: Check the IAM policy attached to `GitHubActionsDeployRole` includes all necessary permissions.

## Next Steps

1. ✅ Set up OIDC and IAM role
2. ✅ Configure GitHub secrets and variables
3. ✅ Deploy Terraform infrastructure
4. ✅ Test the deployment workflow
5. ⬜ Set up additional environments (staging, prod)
6. ⬜ Enable integration tests
7. ⬜ Configure alerts and monitoring
8. ⬜ Document rollback procedures

## Additional Resources

- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS Batch Documentation](https://docs.aws.amazon.com/batch/)
- [Container Deployment Guide](./DEPLOYMENT.md)
- [Terraform Documentation](../../terraform/README.md)

## Support

For questions or issues:

1. Check the [DEPLOYMENT.md](./DEPLOYMENT.md) troubleshooting section
2. Review GitHub Actions workflow logs
3. Check CloudWatch logs for runtime errors
4. Open an issue in the repository
