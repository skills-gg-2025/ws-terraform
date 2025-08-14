resource "aws_instance" "governance_ec2" {
  ami           = "ami-01776cde0c6f0677c"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.ec2_key.key_name

  tags = {
    Name        = "governance-ec2"
    Environment = "production"
  }
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key"
  public_key = file("${path.module}/ec2-key.pem.pub")
}