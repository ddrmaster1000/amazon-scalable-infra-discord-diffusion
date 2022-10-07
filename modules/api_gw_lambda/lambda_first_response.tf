# # All required IAM resources
locals {
  discord_api_to_lambda     = "lambda-api-${var.project_id}"
  log_discord_api_to_lambda = "/aws/lambda/${local.discord_api_to_lambda}"
}

### Discord API First Response ###
resource "aws_lambda_function" "discord_api_to_lambda" {
  function_name    = local.discord_api_to_lambda
  description      = "Discord First Response"
  filename         = "${path.module}/files/discord_api_gw.zip"
  source_code_hash = data.archive_file.discord_api_to_lambda.output_base64sha256
  runtime          = "python3.8"
  role             = aws_iam_role.discord_api_to_lambda.arn
  handler          = "lambda_function.lambda_handler"
  layers = [
    var.requests_arn,
    var.pynacl_arn
  ]
  environment {
    variables = {
      APPLICATION_ID = var.discord_application_id,
      PUBLIC_KEY     = var.discord_public_key,
      SQS_QUEUE_URL  = var.sqs_url
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.discord_api_to_lambda,
    aws_iam_role_policy_attachment.discord_api_to_lambda_sqs,
    aws_cloudwatch_log_group.discord_api_to_lambda,
    data.archive_file.discord_api_to_lambda
  ]
}

data "archive_file" "discord_api_to_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/files/discord_api_gw"
  output_path = "${path.module}/files/discord_api_gw.zip"
}

resource "aws_cloudwatch_log_group" "discord_api_to_lambda" {
  name              = local.log_discord_api_to_lambda
  retention_in_days = 14
}

resource "aws_iam_policy" "discord_api_lambda_logging" {
  name        = "apigw-logging-${var.project_id}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "logs:CreateLogGroup",
        "Resource" : "arn:aws:logs:${var.region}:${var.account_id}:*"
      },
      {
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${var.region}:${var.account_id}:${local.log_discord_api_to_lambda}:*",
        "Effect" : "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_send_sqs_message" {
  name        = "LambdaWriteSQS-${var.project_id}"
  path        = "/"
  description = "IAM policy for writing to sqs queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "sqs:SendMessage",
        "Resource" : "${var.sqs_arn}"
      }
    ]
  })
}

resource "aws_iam_role" "discord_api_to_lambda" {
  name = local.discord_api_to_lambda
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "discord_api_to_lambda" {
  role       = aws_iam_role.discord_api_to_lambda.name
  policy_arn = aws_iam_policy.discord_api_lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "discord_api_to_lambda_sqs" {
  role       = aws_iam_role.discord_api_to_lambda.name
  policy_arn = aws_iam_policy.lambda_send_sqs_message.arn
}

