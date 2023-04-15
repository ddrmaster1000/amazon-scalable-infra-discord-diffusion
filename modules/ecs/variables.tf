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

variable "vpc_id" {
  description = "Pre-exisiting VPC ARN"
  type        = string
}

variable "sqs_queue_url" {
  description = "SQS Queue URL"
  type        = string
}

variable "subnet_a_id" {
  description = "Subnet id 'a' of the created VPC"
  type        = string
}

variable "subnet_b_id" {
  description = "Subnet id 'b' of the created VPC"
  type        = string
}

variable "subnet_c_id" {
  description = "Subnet id 'c' of the created VPC"
  type        = string
}