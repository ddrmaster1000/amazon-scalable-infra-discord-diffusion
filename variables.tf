data "aws_caller_identity" "current" {}

variable "project_id" {
  description = "Overall project name"
  type        = string
  default     = "discord-diffusion"
}

variable "unique_id" {
  description = "Unique identifier for this project"
  type        = string
  default     = "prod"
}

variable "region" {
  description = "AWS region to build infrastructure"
  type        = string
  default     = "us-west-1"
}

variable "discord_application_id" {
  description = "Discord Application ID. Can be found in Discord Developer site"
  type        = number
}

variable "discord_public_key" {
  description = "Discord Application Public Key. Can be found in Discord Developer site"
  type        = string
}

variable "discord_bot_secret" {
  description = "Discord Bot secret. Found in the Discord Developer site under 'Bot'"
  type        = string
}

variable "vpc_id" {
  description = "Pre-exisiting VPC ARN"
  type        = string
}

variable "image_id" {
  description = "Pre-exisiting private ECR in the same region, with path to image that will be run in the ECS Task"
  type        = string
}

variable "git_link" {
  description = "git clone link to repository to turn into an image. WITHOUT https://"
  type        = string
}

variable "git_username" {
  description = "git username with read access to repository of git_link"
  type = string
}

variable "git_password" {
  description = "git password with read access to repository of git_link"
  type = string
}