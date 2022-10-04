# # All required IAM resources



# resource "aws_lambda_function" "discord_api_to_lambda" {
#   function_name    = local.discord_api_to_lambda
#   filename         = "files/discord_stable_diffusion.zip"
#   source_code_hash = filebase64sha256("files/discord_stable_diffusion.zip")
#   runtime          = "python3.8"
#   role             = aws_iam_role.iam_for_lambda.arn
#   handler          = "lambda_function.py"
#   layers           = [aws_lambda_layer_version.requests.arn]

#   depends_on = [
#     aws_iam_role_policy_attachment.discord_api_to_lambda,
#     aws_cloudwatch_log_group.discord_api_to_lambda,
#   ]

# }
locals {
  log_discord_api_to_lambda = "/aws/lambda/${local.discord_api_to_lambda}"
}

# This is to optionally manage the CloudWatch Log Group for the Lambda Function.
resource "aws_cloudwatch_log_group" "discord_api_to_lambda" {
  name              = local.log_discord_api_to_lambda
  retention_in_days = 14
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "discord_api_lambda_logging" {
  name        = "discord-lambda-logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:${local.log_discord_api_to_lambda}:*",
        "Effect" : "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_read_sec_param" {
  name        = "LambdaReadSSMSecrets-${local.project}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Decrypt",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        "Resource" : [
          "arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:alias/aws/ssm",
          "${aws_ssm_parameter.secret.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_send_sqs_message" {
  name        = "LambdaWriteSQS-${local.project}"
  path        = "/"
  description = "IAM policy for writing to sqs queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "sqs:SendMessage",
        "Resource" : "${aws_sqs_queue.default_queue.arn}"
      }
    ]
  })
}

resource "aws_ssm_parameter" "secret" {
  name        = local.discord_api_to_lambda
  description = "Discord Application Secret"
  type        = "SecureString"
  value       = var.discord_application_secret
}

resource "aws_iam_role_policy_attachment" "discord_api_to_lambda" {
  role       = aws_iam_role.discord_api_to_lambda.name
  policy_arn = aws_iam_policy.discord_api_lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "discord_api_to_lambda_ssm" {
  role       = aws_iam_role.discord_api_to_lambda.name
  policy_arn = aws_iam_policy.lambda_read_sec_param.arn
}

resource "aws_iam_role_policy_attachment" "discord_api_to_lambda_sqs" {
  role       = aws_iam_role.discord_api_to_lambda.name
  policy_arn = aws_iam_policy.lambda_send_sqs_message.arn
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