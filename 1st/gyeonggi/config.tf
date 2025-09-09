provider "aws" {
  region = "ap-northeast-2"
}

variable "username" {
  type = string
}

variable "password" {
  type      = string
  sensitive = true
}

variable "number" {
  type = number
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}