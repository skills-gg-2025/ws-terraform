resource "aws_ecr_repository" "green" {
  name = "green"
  
  tags = {
    Name = "green"
  }
}

resource "aws_ecr_repository" "red" {
  name = "red"
  
  tags = {
    Name = "red"
  }
}