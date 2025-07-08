variable "bucket_random_number" {
  description = "4-digit random number for S3 bucket naming"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{4}$", var.bucket_random_number))
    error_message = "Bucket random number must be exactly 4 digits."
  }
}

variable "player_number" {
  description = "Player number for S3 bucket naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}