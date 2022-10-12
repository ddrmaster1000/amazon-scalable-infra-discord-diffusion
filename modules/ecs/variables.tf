variable "project_id" {
  description = "Overall project name"
  type        = string
}

variable "region" {
  description = "AWS region to build infrastructure"
  type        = string
}

variable "vpc_id" {
  description = "Pre-exisiting VPC ARN"
  type        = string
}

variable "sqs_queue_url" {
  description = "SQS Queue URL"
  type        = string
}

variable "image_id" {
  description = "Image id to be run. This is from ECR in this example"
  type        = string
}