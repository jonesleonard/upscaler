# Upscaler Infrastructure

This directory contains Terraform configurations for provisioning and managing the Upscaler project infrastructure on AWS.

## Prerequisites

- Terraform >= 1.9.0
- AWS CLI configured with appropriate credentials
- S3 bucket for Terraform state storage (with versioning enabled)

## Directory Structure

```
src/terraform/
├── main.tf                    # Main configuration and module references
├── providers.tf               # Provider and backend configuration
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output value definitions
├── backend-config.tfvars      # Backend configuration (not in version control)
├── terraform.tfvars.example   # Example variable values
├── .terraform-version         # Required Terraform version
└── modules/
    └── resource_group/        # Resource group module
```

## Setup

1. **Copy the example backend configuration file:**

   ```bash
   cp backend-config.tfvars.example backend-config.tfvars
   ```

2. **Edit `backend-config.tfvars` with your S3 backend details:**

   ```hcl
   bucket       = "your-terraform-state-bucket"
   key          = "dev/terraform.tfstate"
   region       = "us-east-1"
   use_lockfile = true  # Enable S3-native state locking
   ```

3. **Copy the example variables file:**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

4. **Edit `terraform.tfvars` with your actual values:**

   ```hcl
   aws_profile  = "your-aws-profile"
   region       = "us-east-1"
   environment  = "dev"
   project_name = "upscaler"
   ```

5. **Initialize Terraform with backend configuration:**

   ```bash
   terraform init -backend-config=backend-config.tfvars
   ```

## Usage

### Plan Changes

```bash
terraform plan
```

### Apply Changes

```bash
terraform apply
```

### Destroy Resources

```bash
terraform destroy
```

## Best Practices Followed

- ✅ Separate provider configuration in `providers.tf`
- ✅ Version constraints for Terraform and providers
- ✅ Remote state backend with S3
- ✅ S3-native state locking (no DynamoDB required)
- ✅ Modular architecture for reusability
- ✅ Consistent tagging strategy
- ✅ Default tags at provider level
- ✅ Descriptive variable and output names
- ✅ Comprehensive documentation

## State Locking

This configuration uses S3-native state locking via the `use_lockfile = true` backend option. This is the modern approach for state locking that doesn't require a separate DynamoDB table.

**Benefits:**

- Simpler infrastructure (no DynamoDB table needed)
- Lower costs (no additional DynamoDB charges)
- Built-in with S3 backend
- Prevents concurrent state modifications

**Note:** DynamoDB-based locking is deprecated and will be removed in a future Terraform version.

## Security Notes

- Never commit `terraform.tfvars` or `backend-config.tfvars` to version control
- Use AWS IAM roles with least privilege access
- Store sensitive values in AWS Secrets Manager or SSM Parameter Store
- Regularly rotate credentials and review IAM policies

## Outputs

After applying, the following outputs are available:

- `resource_group_arn`: The ARN of the resource group
- `resource_group_name`: The name of the resource group
