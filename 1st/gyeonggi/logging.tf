# S3 Bucket for Fluent Bit configuration
resource "aws_s3_bucket" "fluent_config" {
  bucket        = "ws25-fluent-config-${var.number}"
  force_destroy = true
}

# Fluent Bit configuration for Green
resource "aws_s3_object" "fluent_bit_green_config" {
  bucket  = aws_s3_bucket.fluent_config.bucket
  key     = "fluent-bit-green.conf"
  content = <<EOF
[OUTPUT]
    Name cloudwatch_logs
    Match *
    region ap-northeast-2
    log_group_name /ws25/logs/green
    log_stream_name Green-$${ECS_TASK_ID}
    auto_create_group true

[FILTER]
    Name grep
    Match *
    Exclude log .*\/health.*
EOF
}

# Fluent Bit configuration for Red
resource "aws_s3_object" "fluent_bit_red_config" {
  bucket  = aws_s3_bucket.fluent_config.bucket
  key     = "fluent-bit-red.conf"
  content = <<EOF
[OUTPUT]
    Name cloudwatch_logs
    Match *
    region ap-northeast-2
    log_group_name /ws25/logs/red
    log_stream_name Red-$${ECS_TASK_ID}
    auto_create_group true

[FILTER]
    Name grep
    Match *
    Exclude log .*\/health.*
EOF
}