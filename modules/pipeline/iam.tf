# IAM used for CodeBuilder

resource "aws_iam_role" "codebuild_image_builder" {
  name = "codebuild-image-builder-${var.project_id}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "codebuild.amazonaws.com"
        },
        "Effect" : "Allow",
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_docker_read" {
  name        = "ssm-docker-read-${var.project_id}"
  path        = "/"
  description = "SSM get parameters for dockerLoginPassword"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        "Resource" : aws_ssm_parameter.docker_password.arn
      }
    ]
  })
  depends_on = [
    aws_ssm_parameter.docker_password
  ]
}

resource "aws_iam_policy" "ecr_docker_push" {
  name        = "ecr-docker-push-${var.project_id}"
  path        = "/"
  description = "Push images to ecr repository"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage"
        ],
        "Resource" : "arn:aws:ecr:${var.region}:${var.account_id}:repository/discord-diffusion-image-builds"
      },
      {
        "Effect" : "Allow",
        "Action" : "ecr:GetAuthorizationToken",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "CodeBuildBasePolicy" {
  name        = "CodeBuildBasePolicy-image-builder-${var.project_id}"
  path        = "/"
  description = "CodeBuild base policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Resource" : [
          "${aws_cloudwatch_log_group.image_builder.arn}",
          "${aws_cloudwatch_log_group.image_builder.arn}:*"
        ],
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      },
      {
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::codepipeline-${var.region}-*"
        ],
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
      },
      # {
      #     "Effect": "Allow",
      #     "Resource": [
      #         "arn:aws:codecommit:${var.region}:${var.account_id}:image-builder"
      #     ],
      #     "Action": [
      #         "codecommit:GitPull"
      #     ]
      # },
      # {
      #     "Effect": "Allow",
      #     "Action": [
      #         "codebuild:CreateReportGroup",
      #         "codebuild:CreateReport",
      #         "codebuild:UpdateReport",
      #         "codebuild:BatchPutTestCases",
      #         "codebuild:BatchPutCodeCoverages"
      #     ],
      #     "Resource": [
      #         "arn:aws:codebuild:${var.region}:${var.account_id}:report-group/image-builder-*"
      #     ]
      # }
    ]
  })
}

resource "aws_iam_policy" "codebuild_cloudwatch_logs" {
  name        = "CodeBuildCloudWatchLogsPolicy-${var.project_id}"
  path        = "/"
  description = "Push logs to CloudWatch"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Resource" : [
          aws_cloudwatch_log_group.image_builder.arn,
          "${aws_cloudwatch_log_group.image_builder.arn}:*"
        ],
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_docker_read" {
  role       = aws_iam_role.codebuild_image_builder.name
  policy_arn = resource.aws_iam_policy.ssm_docker_read.arn
}

resource "aws_iam_role_policy_attachment" "ecr_docker_push" {
  role       = aws_iam_role.codebuild_image_builder.name
  policy_arn = resource.aws_iam_policy.ecr_docker_push.arn
}

resource "aws_iam_role_policy_attachment" "CodeBuildBasePolicy" {
  role       = aws_iam_role.codebuild_image_builder.name
  policy_arn = resource.aws_iam_policy.CodeBuildBasePolicy.arn
}

resource "aws_iam_role_policy_attachment" "codebuild_cloudwatch_logs" {
  role       = aws_iam_role.codebuild_image_builder.name
  policy_arn = resource.aws_iam_policy.codebuild_cloudwatch_logs.arn
}