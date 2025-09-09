terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

variable "bucket_suffix" {
  description = "4-character suffix for S3 bucket name"
  type        = string
  validation {
    condition     = length(var.bucket_suffix) == 4 && can(regex("^[a-z]+$", var.bucket_suffix))
    error_message = "Bucket suffix must be exactly 4 lowercase letters."
  }
}