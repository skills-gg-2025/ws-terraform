# KMS Key in Seoul region
resource "aws_kms_key" "wsk_key" {
  description             = "wsk-key"
  deletion_window_in_days = 7
  multi_region            = true

  tags = {
    Name = "wsk-key"
  }
}

resource "aws_kms_alias" "wsk_key_alias" {
  name          = "alias/wsk-key"
  target_key_id = aws_kms_key.wsk_key.key_id
}

# KMS Key replica in Virginia (us-east-1)
resource "aws_kms_replica_key" "wsk_key_us_east_1" {
  provider                = aws.us_east_1
  description             = "wsk-key replica in us-east-1"
  primary_key_arn         = aws_kms_key.wsk_key.arn
  deletion_window_in_days = 7

  tags = {
    Name = "wsk-key"
  }
}

resource "aws_kms_alias" "wsk_key_alias_us_east_1" {
  provider      = aws.us_east_1
  name          = "alias/wsk-key"
  target_key_id = aws_kms_replica_key.wsk_key_us_east_1.key_id
}

# KMS Key replica in Frankfurt (eu-central-1)
resource "aws_kms_replica_key" "wsk_key_eu_central_1" {
  provider                = aws.eu_central_1
  description             = "wsk-key replica in eu-central-1"
  primary_key_arn         = aws_kms_key.wsk_key.arn
  deletion_window_in_days = 7

  tags = {
    Name = "wsk-key"
  }
}

resource "aws_kms_alias" "wsk_key_alias_eu_central_1" {
  provider      = aws.eu_central_1
  name          = "alias/wsk-key"
  target_key_id = aws_kms_replica_key.wsk_key_eu_central_1.key_id
}