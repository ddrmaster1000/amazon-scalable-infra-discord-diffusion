variable "account_id" {
  description = "AWS Account id"
  type        = string
}

variable "project_id" {
  description = "Overall project name"
  type        = string
}

variable "region" {
  description = "AWS region to build infrastructure"
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