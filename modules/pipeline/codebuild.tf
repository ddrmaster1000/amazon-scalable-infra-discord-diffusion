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
      group_name = "/aws/codebuild/${var.project_id}-image-builder"
    }
  }

  source {
    type            = "GITHUB"
    location        = var.git_codebuild
    git_clone_depth = 1
  }
  source_version = var.git_branch
}

resource "aws_cloudwatch_log_group" "image_builder" {
  name              = "/aws/codebuild/${var.project_id}-image-builder"
  retention_in_days = 7
}

resource "aws_ssm_parameter" "docker_password" {
  name        = "/discord_diffusion/dockerLoginPassword"
  type        = "SecureString"
  description = "Docker Password for ${var.project_id}"
  value       = var.docker_password
}

# https://docs.aws.amazon.com/codebuild/latest/userguide/access-tokens.html#access-tokens-github-prereqs : Access your source provider in CodeBuild -  Access token prerequisites
# Requires a 'Tokens (classic)'. I tried with a 'Fine-Grained Tokens' giving all permissions which did not work. 
resource "aws_codebuild_source_credential" "github" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_personal_access_token
}

resource "aws_codebuild_webhook" "image_builder" {
  project_name = aws_codebuild_project.image_builder.name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
  }
}