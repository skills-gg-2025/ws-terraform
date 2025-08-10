# CloudWatch Alarms for ALB
resource "aws_cloudwatch_metric_alarm" "alb_4xx_alarm" {
  alarm_name          = "ws25-alb-4xx-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_ELB_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors ALB 4xx errors"

  dimensions = {
    LoadBalancer = aws_lb.app_alb.arn_suffix
  }

  tags = {
    Name = "ws25-alb-4xx-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_alarm" {
  alarm_name          = "ws25-alb-5xx-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors ALB 5xx errors"

  dimensions = {
    LoadBalancer = aws_lb.app_alb.arn_suffix
  }

  tags = {
    Name = "ws25-alb-5xx-alarm"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "metrics" {
  dashboard_name = "ws25-metrics"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["Custom/VPC", "ws25-hub-vpc-accept"],
            [".", "ws25-app-vpc-accept"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "ap-northeast-2"
          title   = "VPC Flow Log - Accepted Traffic"
          period  = 60
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["Custom/Application", "GreenGETRequests"],
            [".", "GreenPOSTRequests"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "ap-northeast-2"
          title   = "Green Path Requests"
          period  = 60
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["Custom/Application", "RedGETRequests"],
            [".", "RedPOSTRequests"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "ap-northeast-2"
          title   = "Red Path Requests"
          period  = 60
          stat    = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 0
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", aws_lb.app_alb.arn_suffix],
            [".", "HTTPCode_ELB_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "ap-northeast-2"
          title   = "ALB 4xx/5xx Errors"
          period  = 60
          stat    = "Sum"
        }
      }
    ]
  })
}

# Custom Metrics for Path-based Requests (using CloudWatch Logs Insights)
resource "aws_cloudwatch_log_metric_filter" "green_get_requests" {
  name           = "green-get-requests"
  log_group_name = aws_cloudwatch_log_group.green_logs.name
  pattern        = "[timestamp, request_id, ip, method=\"GET\", path=\"/green*\", ...]"

  metric_transformation {
    name      = "GreenGETRequests"
    namespace = "Custom/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "green_post_requests" {
  name           = "green-post-requests"
  log_group_name = aws_cloudwatch_log_group.green_logs.name
  pattern        = "[timestamp, request_id, ip, method=\"POST\", path=\"/green*\", ...]"

  metric_transformation {
    name      = "GreenPOSTRequests"
    namespace = "Custom/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "red_get_requests" {
  name           = "red-get-requests"
  log_group_name = aws_cloudwatch_log_group.red_logs.name
  pattern        = "[timestamp, request_id, ip, method=\"GET\", path=\"/red*\", ...]"

  metric_transformation {
    name      = "RedGETRequests"
    namespace = "Custom/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "red_post_requests" {
  name           = "red-post-requests"
  log_group_name = aws_cloudwatch_log_group.red_logs.name
  pattern        = "[timestamp, request_id, ip, method=\"POST\", path=\"/red*\", ...]"

  metric_transformation {
    name      = "RedPOSTRequests"
    namespace = "Custom/Application"
    value     = "1"
  }
}

# VPC Flow Log Metric Filter
resource "aws_cloudwatch_log_metric_filter" "hub_flow_logs" {
  name           = "ws25-hub-vpc-accept"
  log_group_name = aws_cloudwatch_log_group.hub_flow_logs.name
  pattern        = "ACCEPT"

  metric_transformation {
    name      = "ws25-hub-vpc-accept"
    namespace = "Custom/VPC"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "app_flow_logs" {
  name           = "ws25-app-flow-logs"
  log_group_name = aws_cloudwatch_log_group.app_flow_logs.name
  pattern        = "ACCEPT"

  metric_transformation {
    name      = "ws25-app-vpc-accept"
    namespace = "Custom/VPC"
    value     = "1"
  }
}