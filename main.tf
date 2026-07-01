#
# Terraform state bucket
#

locals {
  state_bucket   = "${var.account_alias}-${var.bucket_purpose}-${var.region}"
  logging_bucket = "${var.account_alias}-${var.bucket_purpose}-${var.log_name}-${var.region}"
}

resource "aws_iam_account_alias" "alias" {
  count         = var.manage_account_alias ? 1 : 0
  account_alias = var.account_alias
}

module "terraform_state_bucket" {
  source  = "trussworks/s3-private-bucket/aws"
  version = "~> 9.0.1"

  bucket         = local.state_bucket
  logging_bucket = local.logging_bucket

  # Keep versioning on the state bucket so a corrupted or accidentally
  # overwritten state file can be recovered. Set explicitly rather than
  # relying on the upstream module default.
  versioning_status = "Enabled"

  use_account_alias_prefix = false
  bucket_key_enabled       = var.bucket_key_enabled
  kms_master_key_id        = var.kms_master_key_id

  enable_s3_public_access_block = var.enable_s3_public_access_block

  depends_on = [
    module.terraform_state_bucket_logs
  ]
}

#
# Terraform state bucket logging
#

module "terraform_state_bucket_logs" {
  source  = "trussworks/logs/aws"
  version = "~> 18.0.0"

  s3_bucket_name          = local.logging_bucket
  default_allow           = false
  allow_s3                = true
  s3_log_bucket_retention = var.log_retention
  versioning_status       = var.log_bucket_versioning
  s3_logs_prefix          = "s3/${local.state_bucket}"
}

#
# Terraform state locking
#
# DynamoDB-based locking is deprecated in favor of native S3 state locking
# (the backend's `use_lockfile = true`). Set enable_dynamodb_state_lock = false
# to skip this table once your backends use the S3 lockfile.

# Ignore warnings about point-in-time recovery since this table holds no data
# The terraform state lock is meant to be ephemeral and does not need recovery
#tfsec:ignore:AWS086
resource "aws_dynamodb_table" "terraform_state_lock" {
  count = var.enable_dynamodb_state_lock ? 1 : 0

  name     = var.dynamodb_table_name
  hash_key = "LockID"

  billing_mode = "PAY_PER_REQUEST"

  server_side_encryption {
    enabled = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.dynamodb_point_in_time_recovery
  }
}
