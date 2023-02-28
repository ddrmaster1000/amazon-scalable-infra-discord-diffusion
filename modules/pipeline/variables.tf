variable "project_id" {
  description = "Overall project name"
  type        = string
}

variable "account_id" {
  description = "AWS Account id"
  type        = string
}

variable "region" {
  description = "AWS region to build infrastructure"
  type        = string
}

variable "ecr_arn" {
  description = "ECR ARN"
  type        = string
}

variable "docker_username" {
  description = "Docker login username"
  type        = string
}

variable "docker_password" {
  description = "Docker login password"
  type        = string
}

variable "git_codebuild" {
  description = "Git clone https url that codebuild uses to build the ecr image"
  type        = string
}

variable "git_branch" {
  description = "Which branch should we trigger builds from? ex: dev main"
  type        = string
}

variable "github_personal_access_token" {
  description = "Personal access token from Github"
  type        = string
}