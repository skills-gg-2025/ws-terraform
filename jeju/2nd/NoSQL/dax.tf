resource "aws_dax_subnet_group" "nsl_dax_subnet_group" {
  name       = "nsl-dax-subnet-group"
  subnet_ids = data.aws_subnets.public.ids
}

resource "aws_iam_role" "dax_service_role" {
  name = "nsl-dax-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dax.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dax_service_role_policy" {
  role       = aws_iam_role.dax_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDaxFullAccess"
}

resource "aws_security_group" "dax_sg" {
  name_prefix = "nsl-dax-sg"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8111
    to_port     = 8111
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_dax_cluster" "nsl_dax" {
  cluster_name       = "nsl-dax"
  iam_role_arn       = aws_iam_role.dax_service_role.arn
  node_type          = "dax.t3.small"
  replication_factor = 3
  subnet_group_name  = aws_dax_subnet_group.nsl_dax_subnet_group.name
  security_group_ids = [aws_security_group.dax_sg.id]

  depends_on = [
    aws_dynamodb_table.orders,
    aws_dynamodb_table.products
  ]
}