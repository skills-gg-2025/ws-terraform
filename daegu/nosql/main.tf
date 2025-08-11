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

# 출력
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "dax_endpoint" {
  value = aws_dax_cluster.main.cluster_address
}

output "api_gateway_url" {
  value = "${aws_api_gateway_rest_api.chat_api.execution_arn}/prod"
}