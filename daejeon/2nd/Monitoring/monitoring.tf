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
          region = "ap-southeast-1"
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
          region = "ap-southeast-1"
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
          region = "ap-southeast-1"
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
          region  = "ap-southeast-1"
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
parse @message /(?<log_date>\d{4}\/\d{2}\/\d{2}) (?<log_time>\d{2}:\d{2}:\d{2}) (?<local_ip>\S+) (?<remote_ip>\S+) (?<method>\S+) (?<path>\S+) (?<status>\d+) (?<size>\d+) (?<referer>\d+) (?<response_time>\S+)/
| filter path = "/healthcheck"
| sort @timestamp desc
| limit 1
| stats latest(@timestamp) as current_time, latest(log_date) as latest_log_date, latest(log_time) as latest_log_time, latest(local_ip) as latest_local_ip, latest(remote_ip) as latest_remote_ip, latest(method) as latest_method, latest(path) as latest_path, latest(status) as latest_status, latest(response_time) as latest_response_time
EOF
}