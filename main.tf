locals {
  unique_project = "${var.project_id}-${var.unique_id}"
}

data "aws_region" "current" {}

module "vpc" {
  source     = "./modules/vpc"
  account_id = data.aws_caller_identity.current.account_id
  project_id = local.unique_project
  region     = data.aws_region.current.name
}

module "dynamodb" {
  source     = "./modules/dynamodb"
  account_id = data.aws_caller_identity.current.account_id
  project_id = local.unique_project
  region     = data.aws_region.current.name
}

# API Gateway, Discord Lambda handler, and SQS
module "api_gw_lambda" {
  source                 = "./modules/api_lambda_sqs"
  account_id             = data.aws_caller_identity.current.account_id
  project_id             = local.unique_project
  region                 = data.aws_region.current.name
  discord_application_id = var.discord_application_id
  discord_public_key     = var.discord_public_key
  pynacl_arn             = aws_lambda_layer_version.pynacl.arn
  requests_arn           = aws_lambda_layer_version.requests.arn
  dynamodb_table_name    = module.dynamodb.dynamodb_table_name
  dynamodb_arn           = module.dynamodb.dynamodb_arn
  depends_on = [
    module.dynamodb
  ]
}

# A Lambda function that creates the Discord UI
module "discord_ui" {
  source                 = "./modules/discord_ui"
  account_id             = data.aws_caller_identity.current.account_id
  project_id             = local.unique_project
  region                 = data.aws_region.current.name
  discord_application_id = var.discord_application_id
  requests_arn           = aws_lambda_layer_version.requests.arn
  discord_bot_secret     = var.discord_bot_secret
}

# The ECS cluster with GPUs
module "ecs_cluster" {
  source        = "./modules/ecs"
  project_id    = local.unique_project
  account_id    = data.aws_caller_identity.current.account_id
  region        = data.aws_region.current.name
  vpc_id        = module.vpc.vpc_id
  sqs_queue_url = module.api_gw_lambda.sqs_queue_url
  subnet_a_id   = module.vpc.subnet_a_id
  subnet_b_id   = module.vpc.subnet_b_id
  subnet_c_id   = module.vpc.subnet_c_id
  depends_on = [
    module.api_gw_lambda,
    module.vpc
  ]
}

# Alarms for scaling, and Lambda for pushing custom Metrics to CloudWatch
module "metrics_scaling" {
  source          = "./modules/scaling_alarm_lambda"
  project_id      = local.unique_project
  region          = data.aws_region.current.name
  vpc_id          = module.vpc.vpc_id
  account_id      = data.aws_caller_identity.current.account_id
  sqs_queue_url   = module.api_gw_lambda.sqs_queue_url
  asg_name        = module.ecs_cluster.asg_name
  asg_arn         = module.ecs_cluster.asg_arn
  ecs_service_arn = module.ecs_cluster.ecs_service_arn
  depends_on = [
    module.ecs_cluster,
    module.api_gw_lambda,
    module.vpc
  ]
}

# cicd pipeline for the ecr image
module "pipeline" {
  source                       = "./modules/pipeline"
  project_id                   = local.unique_project
  region                       = data.aws_region.current.name
  account_id                   = data.aws_caller_identity.current.account_id
  ecr_arn                      = module.ecs_cluster.ecr_registry_arn
  docker_username              = var.docker_username
  git_codebuild                = var.git_codebuild
  git_branch                   = var.git_branch
  docker_password              = var.docker_password
  github_personal_access_token = var.github_personal_access_token
  depends_on = [
    module.ecs_cluster,
    module.api_gw_lambda,
    module.metrics_scaling
  ]
}

# Lambda layers to be used for all Lambda functions
resource "aws_lambda_layer_version" "requests" {
  filename                 = "files/requests_layer_arm64.zip"
  layer_name               = "${local.unique_project}-requests"
  compatible_runtimes      = ["python3.8"]
  compatible_architectures = ["arm64"]
}

resource "aws_lambda_layer_version" "pynacl" {
  filename                 = "files/pynacl_layer_arm64.zip"
  layer_name               = "${local.unique_project}-pynacl"
  compatible_runtimes      = ["python3.8"]
  compatible_architectures = ["arm64"]
}
