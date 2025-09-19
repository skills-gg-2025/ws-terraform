

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

  custom_data_identifier_ids = [ aws_macie2_custom_data_identifier.credit_cards.id,
                                 aws_macie2_custom_data_identifier.emails.id,
                                 aws_macie2_custom_data_identifier.names.id,
                                 aws_macie2_custom_data_identifier.phones.id,
                                 aws_macie2_custom_data_identifier.ssns.id,
                                 aws_macie2_custom_data_identifier.uuids.id ]

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [time_sleep.wait_for_macie]
}


resource "aws_macie2_custom_data_identifier" "names" {
  name                   = "NAMES"
  regex                  = "^[A-Za-z]+ [A-Za-z]+$"

  depends_on = [aws_macie2_account.main]
}

resource "aws_macie2_custom_data_identifier" "emails" {
  name                   = "EMAILS"
  regex                  = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

  depends_on = [aws_macie2_account.main]
}

resource "aws_macie2_custom_data_identifier" "ssns" {
  name                   = "SSNS"
  regex                  = "^\\d{3}-\\d{2}-\\d{4}$"

  depends_on = [aws_macie2_account.main]
}

resource "aws_macie2_custom_data_identifier" "phones" {
  name                   = "PHONES"
  regex                  = "^\\d{3}-\\d{4}-\\d{4}$"

  depends_on = [aws_macie2_account.main]
}

resource "aws_macie2_custom_data_identifier" "credit_cards" {
  name                   = "CREDIT CARDS"
  regex                  = "^\\d{4}-\\d{4}-\\d{4}-\\d{4}$"

  depends_on = [aws_macie2_account.main]
}

resource "aws_macie2_custom_data_identifier" "uuids" {
  name                   = "UUIDS"
  regex                  = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

  depends_on = [aws_macie2_account.main]
}



data "aws_caller_identity" "current" {}