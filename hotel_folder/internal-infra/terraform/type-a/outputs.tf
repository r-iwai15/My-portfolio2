output "vpc_id" {
  value       = aws_vpc.main.id
  description = "Private-only VPC (attach Verified Access in full design)."
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Private subnets for Lambda / ECS workloads."
}

output "conversation_table_name" {
  value       = aws_dynamodb_table.conversation_history.name
  description = "DynamoDB table for RAG / chat history."
}
