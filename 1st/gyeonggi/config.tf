provider "aws" {
  region = "ap-northeast-2"
}

variable "username" {
  type        = string
  description = "Database username"
}

variable "password" {
  type        = string
  sensitive   = true
  description = "Database password"
}

variable "number" {
  type        = number
  description = "Project number"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}