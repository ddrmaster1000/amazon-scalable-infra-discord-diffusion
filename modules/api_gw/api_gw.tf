resource "aws_apigatewayv2_api" "discord_gw" {
  name          = "discord-diffusion"
  description = "HTTP Gateway for Discord Requests"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["*"]
    allow_methods = ["OPTIONS", "PUT"]
    allow_origins = ["https://discord.com"]
  }
  ## Note: payload_format_version must be version 2.0 for this project
  target = aws_lambda_function.discord_api_to_lambda.arn
  route_key = "POST /"
  depends_on = [
    aws_lambda_function.discord_api_to_lambda
  ]
}

# resource "aws_lambda_permission" "apigw_lambda" {
#   statement_id  = "AllowExecutionFromAPIGateway"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.discord_api_to_lambda.function_name
#   principal     = "apigateway.amazonaws.com"

#   # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
#   source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.api.id}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.resource.path}"
# }
