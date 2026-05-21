output "blocked_ips_table_name" {
  value = aws_dynamodb_table.blocked_ips.name
}

output "blocked_ips_table_arn" {
  value = aws_dynamodb_table.blocked_ips.arn
}

output "executioner_function_name" {
  value = aws_lambda_function.sentinel_executioner.function_name
}

output "release_function_name" {
  value = aws_lambda_function.sentinel_release.function_name
}
