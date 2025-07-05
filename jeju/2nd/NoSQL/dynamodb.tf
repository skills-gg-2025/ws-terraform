resource "aws_dynamodb_table" "users" {
  name           = "Users"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "UserId"

  attribute {
    name = "UserId"
    type = "S"
  }

  tags = {
    Name = "Users"
  }
}

resource "aws_dynamodb_table" "orders" {
  name           = "Orders"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "OrderId"

  attribute {
    name = "OrderId"
    type = "S"
  }

  attribute {
    name = "UserId"
    type = "S"
  }

  global_secondary_index {
    name            = "UserId-index"
    hash_key        = "UserId"
    projection_type = "ALL"
  }

  tags = {
    Name = "Orders"
  }
}

resource "aws_dynamodb_table" "order_items" {
  name           = "OrderItems"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "OrderId"

  attribute {
    name = "OrderId"
    type = "S"
  }

  global_secondary_index {
    name            = "OrderId-index"
    hash_key        = "OrderId"
    projection_type = "ALL"
  }

  tags = {
    Name = "OrderItems"
  }
}

resource "aws_dynamodb_table" "products" {
  name           = "Products"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ProductId"

  attribute {
    name = "ProductId"
    type = "S"
  }

  tags = {
    Name = "Products"
  }
}

resource "aws_dynamodb_table" "categories" {
  name           = "Categories"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "CategoryId"

  attribute {
    name = "CategoryId"
    type = "S"
  }

  tags = {
    Name = "Categories"
  }
}