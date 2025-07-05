# Kinesis Data Streams
resource "aws_kinesis_stream" "input_stream" {
  name = "input-stream"
  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = {
    Name = "input-stream"
  }
}

resource "aws_kinesis_stream" "output_stream" {
  name = "output-stream"
  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = {
    Name = "output-stream"
  }
}

# IAM Role for Firehose
resource "aws_iam_role" "firehose_role" {
  name = "firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "firehose-policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.ws_day2_data.arn,
          "${aws_s3_bucket.ws_day2_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords"
        ]
        Resource = aws_kinesis_stream.output_stream.arn
      }
    ]
  })
}

# Kinesis Data Firehose
resource "aws_kinesis_firehose_delivery_stream" "ws_data_firehose" {
  name        = "ws-data-firehose"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.output_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.ws_day2_data.arn
    buffering_size     = 1
    buffering_interval = 0
    compression_format = "UNCOMPRESSED"
  }

  tags = {
    Name = "ws-data-firehose"
  }
}