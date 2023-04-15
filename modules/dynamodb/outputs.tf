output "dynamodb_table_name" {
  value = aws_dynamodb_table.user_queries.id
}

output "dynamodb_arn" {
  value = aws_dynamodb_table.user_queries.arn
}