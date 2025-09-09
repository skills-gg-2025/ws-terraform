# Default VPC for Korea region
resource "aws_default_vpc" "default_kr" {
  provider = aws.korea

  tags = {
    Name = "default-vpc-kr"
  }
}

# Default VPC for US region
resource "aws_default_vpc" "default_us" {
  provider = aws.us

  tags = {
    Name = "default-vpc-us"
  }
}

# Default subnet for bastion (Korea)
data "aws_subnets" "default_kr" {
  provider = aws.korea

  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default_kr.id]
  }
}

# Default security group for Korea
data "aws_security_group" "default_kr" {
  provider = aws.korea
  vpc_id   = aws_default_vpc.default_kr.id
  name     = "default"
}
