terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 가용 영역 데이터 소스
data "aws_availability_zones" "available" {
  state = "available"
}