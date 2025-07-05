# DynamoDB table
resource "aws_dynamodb_table" "consumer_id" {
  name           = "Consumer_id"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  deletion_protection_enabled = true

  tags = {
    Name = "Consumer_id"
  }
}