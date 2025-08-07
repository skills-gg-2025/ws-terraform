# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "app_dashboard" {
  dashboard_name = "wsi-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # wsi-success Widget
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app_alb.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = "us-west-1"
          title  = "wsi-success"
        }
      },
      # wsi-fail Widget
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetConnectionErrorCount", "LoadBalancer", aws_lb.app_alb.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = "us-west-1"
          title  = "wsi-fail"
        }
      },
      # wsi-sli Widget (Success Rate Gauge)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            [{ expression = "m1/(m1+m2)*100", label = "Success Rate (%)", id = "e1" }],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app_alb.arn_suffix, { id = "m1", visible = false }],
            ["AWS/ApplicationELB", "TargetConnectionErrorCount", "LoadBalancer", aws_lb.app_alb.arn_suffix, { id = "m2", visible = false }]
          ]
          view   = "gauge"
          region = "us-west-1"
          title  = "wsi-sli"
          period = 300
          stat   = "Sum"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      # wsi-p90-p96-p99 Widget
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app_alb.arn_suffix, { stat = "p90" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app_alb.arn_suffix, { stat = "p95" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app_alb.arn_suffix, { stat = "p99" }]
          ]
          period  = 60
          region  = "us-west-1"
          title   = "wsi-p90-p96-p99"
          view    = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}

# CloudWatch Log Insights Query
resource "aws_cloudwatch_query_definition" "app_query" {
  name = "wsi-query"

  log_group_names = [
    aws_cloudwatch_log_group.app_logs.name
  ]

  query_string = <<EOF
parse @message "* * * * * * * *" as raw_date, raw_time, raw_src_ip, raw_dst_ip, http_method, http_path, http_status, http_duration
| filter abs(toMillis(now()) - toMillis(@timestamp)) <= 60000
| sort @timestamp desc
| fields raw_date as date, raw_time as time, raw_src_ip as src_ip, raw_dst_ip as dst_ip, http_method as method, http_path as path, http_status as status, http_duration as duration
EOF
}