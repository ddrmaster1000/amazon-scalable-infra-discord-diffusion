locals {
  log_discord_ui = "/aws/lambda/discord-ui-${local.project}"
}

### Discord UI ###
resource "aws_lambda_function" "discord_ui" {
  function_name    = "discord-ui-${local.project}"
  description      = "Discord UI"
  filename         = "${path.module}/files/discord_ui.zip"
  source_code_hash = data.archive_file.discord_ui.output_base64sha256
  runtime          = "python3.8"
  role             = aws_iam_role.discord_ui.arn
  handler          = "lambda_function.lambda_handler"
  layers           = [aws_lambda_layer_version.requests.arn]
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
  name        = "DISCORD_TOKEN"
  description = "Discord Application Secret"
  type        = "SecureString"
  value       = var.discord_application_secret
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
  name        = "discord-ui-logging-${local.project}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "logs:CreateLogGroup",
        "Resource" : "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:${local.log_discord_ui}:*",
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

resource "aws_iam_role" "discord_ui" {
  name = "discord-ui-${local.project}"
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