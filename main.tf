locals {
  unique_project = "${var.project_id}-${var.unique_id}"
}

module "api_gw_lambda" {
  source                 = "./modules/api_gw_lambda"
  account_id             = data.aws_caller_identity.current.account_id
  project_id             = local.unique_project
  region                 = var.region
  discord_application_id = var.discord_application_id
  discord_public_key     = var.discord_public_key
  sqs_arn                = aws_sqs_queue.default_queue.arn
  sqs_url                = aws_sqs_queue.default_queue.url
  pynacl_arn             = aws_lambda_layer_version.pynacl.arn
  requests_arn           = aws_lambda_layer_version.requests.arn
}

# Create the SQS Queue
resource "aws_sqs_queue" "default_queue" {
  name_prefix                = local.unique_project
  visibility_timeout_seconds = 120
  max_message_size           = 262144
  receive_wait_time_seconds  = 20

  fifo_queue                  = true
  content_based_deduplication = true
}

# # Create First Response Lambda Function
# Lambda layers to be used for all Lambda functions
resource "aws_lambda_layer_version" "requests" {
  filename            = "files/requests_py3p8.zip"
  layer_name          = "${local.unique_project}-requests"
  compatible_runtimes = ["python3.8"]
}

resource "aws_lambda_layer_version" "pynacl" {
  filename            = "files/pynacl_py3p8.zip"
  layer_name          = "${local.unique_project}-pynacl"
  compatible_runtimes = ["python3.8"]
}





# resource "aws_apigatewayv2_api" "default_gateway" {
#   name          = "${var.project_id}-${var.unique_id}"
#   description   = "API Gateway for initial Discord interaction"
#   protocol_type = "HTTP"
# #   cors_configuration {
# #     allow_origins = ["https://discord.com"]
# #     allow_methods = ["POST", "OPTIONS"]
# #     allow_headers = ["*"]
# #     max_age       = 180
# #   }
#   #   target = "LAMBDA.arn"
# }