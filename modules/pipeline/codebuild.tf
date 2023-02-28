# Codebuild setup

resource "aws_codebuild_project" "image_builder" {
  name          = "image-builder-${var.project_id}"
  description   = "Image builder for ${var.project_id}"
  build_timeout = "30"
  service_role  = aws_iam_role.codebuild_image_builder.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:6.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "DOCKER_USERNAME"
      value = var.docker_username
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.project_id
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild"
      stream_name = "image-builder-${var.project_id}"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/ddrmaster1000/amazon-scalable-discord-diffusion.git"
    git_clone_depth = 1
  }
  source_version = "dev"
}

resource "aws_cloudwatch_log_group" "image_builder" {
  name              = "codebuilder/${var.project_id}-image-builder"
  retention_in_days = 7
}

