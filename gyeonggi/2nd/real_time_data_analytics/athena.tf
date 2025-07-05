# Athena Workgroup
resource "aws_athena_workgroup" "ws_workgroup" {
  name          = "ws-workgroup"
  force_destroy = true

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.ws_day2_athena.bucket}/"
    }
  }

  tags = {
    Name = "ws-workgroup"
  }
}

# Glue Database
resource "aws_glue_catalog_database" "ws_database" {
  name = "ws"

  tags = {
    Name = "ws"
  }
}

# Glue Table
resource "aws_glue_catalog_table" "analytics_table" {
  name          = "analytics_table"
  database_name = aws_glue_catalog_database.ws_database.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "json"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.ws_day2_data.bucket}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "level"
      type = "string"
    }

    columns {
      name = "window_start"
      type = "timestamp"
    }

    columns {
      name = "window_end"
      type = "timestamp"
    }

    columns {
      name = "counts"
      type = "bigint"
    }
  }
}

# Athena Named Query
resource "aws_athena_named_query" "level_analytics" {
  name      = "LevelAnalytics"
  database  = aws_glue_catalog_database.ws_database.name
  workgroup = aws_athena_workgroup.ws_workgroup.name
  query     = "SELECT level, window_start, window_end, counts FROM analytics_table ORDER BY window_start, window_end;"

  description = "Query to analyze log levels by window time"
}