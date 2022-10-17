terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      auto-delete = "no"
      Project     = var.project_id
    }
  }
}
