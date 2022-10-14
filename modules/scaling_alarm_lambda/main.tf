# Alarms for scaling, and Lambda for pushing custom Metrics to CloudWatch

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
    aws_iam_role_policy_attachment.describe_ecs_services,
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

resource "aws_iam_policy" "describe_ecs_services" {
  name        = "describeECSServices-${var.project_id}"
  path        = "/"
  description = "Describe ECS Services"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "ecs:DescribeServices",
        "Resource" : "*"
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

resource "aws_iam_role_policy_attachment" "describe_ecs_services" {
  role       = aws_iam_role.lamdba_cw_metric.name
  policy_arn = aws_iam_policy.describe_ecs_services.arn
}


# AutoScaling Group
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = "Public"
  }
}

# resource "aws_autoscaling_group" "asg" {
#   name                      = "asg-${var.project_id}"
#   max_size                  = 5
#   min_size                  = 0
#   health_check_grace_period = 0
#   health_check_type         = "EC2"
#   desired_capacity          = 0
#   launch_template {
#       id      = aws_launch_template.foobar.id
#       version = "$Latest"
#     }
#   vpc_zone_identifier       =   toset(data.aws_subnets.public.ids)

#   timeouts {
#     delete = "15m"
#   }

#   tag {
#     key                 = "lorem"
#     value               = "ipsum"
#     propagate_at_launch = false
#   }
# }

### Step Function ###
resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = var.project_id
  role_arn = aws_iam_role.step_function.arn
  type     = "EXPRESS"

  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Lambda Invoke",
  "States": {
    "Lambda Invoke": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Wait"
    },
    "Wait": {
      "Type": "Wait",
      "Seconds": 15,
      "Next": "Lambda Invoke (1)"
    },
    "Lambda Invoke (1)": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Wait (2)"
    },
    "Wait (2)": {
      "Type": "Wait",
      "Seconds": 15,
      "Next": "Lambda Invoke (2)"
    },
    "Lambda Invoke (2)": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Wait (1)"
    },
    "Wait (1)": {
      "Type": "Wait",
      "Seconds": 15,
      "Next": "Lambda Invoke (3)"
    },
    "Lambda Invoke (3)": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.lamdba_cw_metric.arn}",
        "Payload": {
          "queueUrl": "${var.sqs_queue_url}",
          "queueName": "${var.project_id}.fifo",
          "accountId": "${var.account_id}",
          "service_name": "${var.project_id}",
          "cluster_name": "${var.project_id}",
          "acceptable_latency": "90",
          "time_process_per_message": "15"
        }
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "End": true
    }
  }
}
EOF
}

resource "aws_iam_role" "step_function" {
  name = "stepFunction-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "states.amazonaws.com"
        },
        "Effect" : "Allow",
      }
    ]
  })
}

resource "aws_iam_policy" "step_lambda" {
  name        = "stepLambda-${var.project_id}"
  path        = "/"
  description = "IAM policy for running lambda for step function"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Resource" : [
          "${aws_lambda_function.lamdba_cw_metric.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "step_xray" {
  name        = "xray-${var.project_id}"
  path        = "/"
  description = "IAM policy for logging via xray"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_lambda" {
  role       = aws_iam_role.step_function.name
  policy_arn = aws_iam_policy.step_lambda.arn
}

resource "aws_iam_role_policy_attachment" "step_xray" {
  role       = aws_iam_role.step_function.name
  policy_arn = aws_iam_policy.step_xray.arn
}

### EventBridge Rule to trigger Step Function
resource "aws_cloudwatch_event_rule" "discord_cw" {
  name        = "eventRule-${var.project_id}"
  description = "Trigger CW Lambda for custom metric every minute"

  # Cron for every minute
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "discord_cw" {
  rule      = aws_cloudwatch_event_rule.discord_cw.name
  target_id = "TriggerStepCWMetric"
  arn       = aws_sfn_state_machine.sfn_state_machine.arn
  role_arn  = aws_iam_role.event_rule.arn
}

resource "aws_iam_role" "event_rule" {
  name = "eventRule-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "events.amazonaws.com"
        },
        "Effect" : "Allow",
      }
    ]
  })
}

resource "aws_iam_policy" "event_rule" {
  name        = "eventRule-${var.project_id}"
  path        = "/"
  description = "IAM policy for triggering step function"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "states:StartExecution"
        ],
        "Resource" : [
          "${aws_sfn_state_machine.sfn_state_machine.arn}",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "event_rule" {
  role       = aws_iam_role.event_rule.name
  policy_arn = aws_iam_policy.event_rule.arn
}