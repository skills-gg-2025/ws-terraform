// CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "monitoring_dashboard" {
  dashboard_name = "Ws-skills-${var.number}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.moni_cluster.name, "ServiceName", aws_ecs_service.moni_ser.name]
          ]
          period = 60
          stat   = "Average"
          region = data.aws_region.current.region
          title  = "ECS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.moni_alb.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = data.aws_region.current.region
          title  = "ALB Request Count"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", aws_lb.moni_alb.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = data.aws_region.current.region
          title  = "ALB Target 4XX Errors"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.moni_alb.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = data.aws_region.current.region
          title  = "ALB Target 5XX Errors"
        }
      }
    ]
  })
}

// CloudWatch Alarm for 4XX Errors
resource "aws_cloudwatch_metric_alarm" "alb_4xx_errors" {
  alarm_name          = "alb-4xx-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300 // 5 minutes
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This alarm monitors for excessive 4XX errors (10+ in 5 minutes)"

  dimensions = {
    LoadBalancer = aws_lb.moni_alb.arn_suffix
  }
}

// CloudWatch Alarm for 5XX Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "alb-5xx-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300 // 5 minutes
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This alarm monitors for excessive 5XX errors (10+ in 5 minutes)"

  dimensions = {
    LoadBalancer = aws_lb.moni_alb.arn_suffix
  }
}