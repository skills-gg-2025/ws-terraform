# DynamoDB 테이블
resource "aws_dynamodb_table" "chat_messages" {
  name           = "chat-messages"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "RoomID"
  range_key      = "Timestamp"
  
  attribute {
    name = "RoomID"
    type = "S"
  }
  
  attribute {
    name = "Timestamp"
    type = "S"
  }
  
  tags = {
    Name = "chat-messages"
  }
}

# DAX 서브넷 그룹
resource "aws_dax_subnet_group" "main" {
  name       = "chat-dax-subnet-group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.private.id]
}

# DAX 클러스터
resource "aws_dax_cluster" "main" {
  cluster_name       = "chat-dax-cluster"
  iam_role_arn       = aws_iam_role.dax.arn
  node_type          = "dax.t3.small"
  replication_factor = 1
  
  subnet_group_name   = aws_dax_subnet_group.main.name
  security_group_ids  = [aws_security_group.dax.id]
  
  depends_on = [aws_iam_role_policy.dax_policy]
}