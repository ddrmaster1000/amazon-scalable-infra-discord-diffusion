# A Lambda function that creates the Discord UI
locals {
  log_discord_ui = "/aws/lambda/discord-ui-${var.project_id}"
}

### Discord UI ###
resource "aws_lambda_function" "discord_ui" {
  function_name    = "discord-ui-${var.project_id}"
  description      = "Discord UI"
  filename         = "${path.module}/files/discord_ui.zip"
  source_code_hash = data.archive_file.discord_ui.output_base64sha256
  runtime          = "python3.8"
  role             = aws_iam_role.discord_ui.arn
  handler          = "lambda_function.lambda_handler"
  layers           = [var.requests_arn]
  environment {
    variables = {
      APPLICATION_ID = var.discord_application_id
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.discord_ui_ssm,
    aws_iam_role_policy_attachment.discord_ui_logging,
    aws_cloudwatch_log_group.discord_ui,
  ]
}

resource "aws_ssm_parameter" "secret" {
  name        = "BOT_TOKEN"
  description = "Discord Bot Secret"
  type        = "SecureString"
  value       = var.discord_bot_secret
}

data "archive_file" "discord_ui" {
  type        = "zip"
  source_dir  = "${path.module}/files/discord_ui"
  output_path = "${path.module}/files/discord_ui.zip"
}

resource "aws_cloudwatch_log_group" "discord_ui" {
  name              = local.log_discord_ui
  retention_in_days = 14
}

resource "aws_iam_policy" "discord_ui" {
  name        = "discord-ui-logging-${var.project_id}"
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
        "Resource" : "arn:aws:logs:${var.region}:${var.account_id}:log-group:${local.log_discord_ui}:*",
        "Effect" : "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_read_sec_param" {
  name        = "LambdaReadSSMSecrets-${var.project_id}"
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
          "arn:aws:kms:*:${var.account_id}:alias/aws/ssm",
          "${aws_ssm_parameter.secret.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "discord_ui" {
  name = "discord-ui-${var.project_id}"
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

resource "aws_iam_role_policy_attachment" "discord_ui_ssm" {
  role       = aws_iam_role.discord_ui.name
  policy_arn = aws_iam_policy.lambda_read_sec_param.arn
}

resource "aws_iam_role_policy_attachment" "discord_ui_logging" {
  role       = aws_iam_role.discord_ui.name
  policy_arn = aws_iam_policy.discord_ui.arn
}