# Lambda to publish custom CloudWatch Metric. 
# Metric will be used for Autoscaling ECS Service's Tasks and instances running 
locals {
  log_lamdba_cw_metric = "/aws/lambda/lamdba-cw-metric-${var.project_id}"
}

# Lambda Function for custom CloudWatch Metrics
resource "aws_lambda_function" "lamdba_cw_metric" {
  function_name    = "lambda-cw-metric-${var.project_id}"
  description      = "Custom Metric for scaling instances running"
  filename         = "${path.module}/files/custom_cw_metric.zip"
  source_code_hash = data.archive_file.lamdba_cw_metric.output_base64sha256
  runtime          = "python3.8"
  architectures    = ["arm64"]
  role             = aws_iam_role.lamdba_cw_metric.arn
  handler          = "custom_cw_metric.lambda_handler"

  depends_on = [
    aws_iam_role_policy_attachment.CloudWatchAgentServerPolicy,
    aws_iam_role_policy_attachment.AmazonSQSReadOnlyAccess,
    aws_iam_role_policy_attachment.describe_ecs_service,
    aws_cloudwatch_log_group.lamdba_cw_metric,
    data.archive_file.lamdba_cw_metric
  ]
}

data "archive_file" "lamdba_cw_metric" {
  type        = "zip"
  source_dir  = "${path.module}/files/custom_cw_metric"
  output_path = "${path.module}/files/custom_cw_metric.zip"
}

resource "aws_cloudwatch_log_group" "lamdba_cw_metric" {
  name              = local.log_lamdba_cw_metric
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_cw_metric_lambda_logging" {
  name        = "lambda-cw-metric-logging-${var.project_id}"
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
        "Resource" : "arn:aws:logs:${var.region}:${var.account_id}:log-group:${local.log_lamdba_cw_metric}:*",
        "Effect" : "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "describe_ecs_service" {
  name        = "describeECSServices-${var.project_id}"
  path        = "/"
  description = "Describe ECS Service"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "ecs:DescribeServices",
        "Resource" : "${var.ecs_service_arn}"
      }
    ]
  })
}

resource "aws_iam_role" "lamdba_cw_metric" {
  name = "lambda-cw-metric-${var.project_id}"
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

data "aws_iam_policy" "CloudWatchAgentServerPolicy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy" "AmazonSQSReadOnlyAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  role       = aws_iam_role.lamdba_cw_metric.name
  policy_arn = data.aws_iam_policy.CloudWatchAgentServerPolicy.arn
}

resource "aws_iam_role_policy_attachment" "AmazonSQSReadOnlyAccess" {
  role       = aws_iam_role.lamdba_cw_metric.name
  policy_arn = data.aws_iam_policy.AmazonSQSReadOnlyAccess.arn
}

resource "aws_iam_role_policy_attachment" "describe_ecs_service" {
  role       = aws_iam_role.lamdba_cw_metric.name
  policy_arn = aws_iam_policy.describe_ecs_service.arn
}