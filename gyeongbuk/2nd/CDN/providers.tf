terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-northeast-2"
  alias  = "korea"
}

provider "aws" {
  region = "us-east-1"
  alias  = "us"
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current region
data "aws_region" "current" {
  provider = aws.korea
}

# Data source to get current region for US
data "aws_region" "us" {
  provider = aws.us
}
