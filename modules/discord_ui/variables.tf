variable "account_id" {
  description = "AWS Account id"
  type          = string
}

variable "project_id" {
  description = "Overall project name"
  type        = string
}

variable "region" {
  description = "AWS region to build infrastructure"
  type        = string
}

variable "discord_application_id" {
  description = "Discord Application ID. Can be found in Discord Developer site"
  type        = number
}

variable "discord_application_secret" {
  description = "Discord application secret. Found in teh Dicscord Developer site"
  type        = string
}

variable "requests_arn" {
  description = "Lambda Layer request's arn"
  type = string
}