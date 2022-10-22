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

variable "vpc_id" {
  description = "Pre-exisiting VPC ARN"
  type        = string
}