output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr_block" {
  value = aws_vpc.main.cidr_block
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_1a.id, aws_subnet.public_1c.id]
}

output "subnet_public_1a_id" {
  value = aws_subnet.public_1a.id
}

output "subnet_public_1c_id" {
  value = aws_subnet.public_1c.id
}

output "subnet_app_1a_id" {
  value = aws_subnet.app_1a.id
}

output "subnet_app_1c_id" {
  value = aws_subnet.app_1c.id
}

output "subnet_db_1a_id" {
  value = aws_subnet.db_1a.id
}

output "subnet_db_1c_id" {
  value = aws_subnet.db_1c.id
}

output "subnet_lambda_1a_id" {
  value = aws_subnet.lambda_1a.id
}

output "subnet_lambda_1c_id" {
  value = aws_subnet.lambda_1c.id
}

output "subnet_llm_1a_id" {
  value = aws_subnet.llm_1a.id
}

output "lambda_subnet_ids" {
  value = [aws_subnet.lambda_1a.id, aws_subnet.lambda_1c.id]
}

output "db_subnet_ids" {
  value = [aws_subnet.db_1a.id, aws_subnet.db_1c.id]
}

output "app_subnet_ids" {
  value = [aws_subnet.app_1a.id, aws_subnet.app_1c.id]
}
