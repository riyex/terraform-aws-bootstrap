output "state_bucket" {
  description = "The state_bucket name"
  value       = local.state_bucket
}

output "logging_bucket" {
  description = "The logging_bucket name"
  value       = local.logging_bucket
}

output "dynamodb_table" {
  description = "The name of the dynamo db table, or null when enable_dynamodb_state_lock is false"
  value       = one(aws_dynamodb_table.terraform_state_lock[*].id)
}
