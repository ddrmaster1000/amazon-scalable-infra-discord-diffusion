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

variable "huggingface_username" {
  description = "Username to the website hugging face. Used to download models."
  type        = string
}

variable "huggingface_password" {
  description = "Password to the website hugging face. Used to download models."
  type        = string
}

variable "vpc_id" {
  description = "Pre-exisiting VPC ARN"
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