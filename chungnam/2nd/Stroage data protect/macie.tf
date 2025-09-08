

resource "aws_macie2_account" "main" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                      = "ENABLED"
}

resource "time_sleep" "wait_for_macie" {
  depends_on = [aws_macie2_account.main]
  create_duration = "60s"
}





resource "aws_macie2_classification_job" "sensor_job" {
  job_type = "ONE_TIME"
  name     = "wsc2025-sensor-job"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.sensitive_data.bucket]
    }

    scoping {
      includes {
        and {
          simple_scope_term {
            comparator = "STARTS_WITH"
            key        = "OBJECT_KEY"
            values     = ["masked/"]
          }
        }
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [time_sleep.wait_for_macie]
}



data "aws_caller_identity" "current" {}