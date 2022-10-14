# Alarms the autoscaling group up and down.
# TODO: this

resource "aws_cloudwatch_metric_alarm" "scale_down" {
  alarm_name                = "scale-down-${var.project_id}"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "150"
  datapoints_to_alarm       = "150"
  metric_name               = "ScaleAdjustmentTaskCount"
  namespace                 = "SQS Based Scaling Metrics"
  period                    = "10"
  statistic                 = "Average"
  threshold                 = "-1"
  alarm_description         = "This metric monitors the down scaling of EC2s based on Discord requests vs running EC2."
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_name                = "scale-up-${var.project_id}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  datapoints_to_alarm       = "2"
  metric_name               = "ScaleAdjustmentTaskCount"
  namespace                 = "SQS Based Scaling Metrics"
  period                    = "10"
  statistic                 = "Average"
  threshold                 = "1"
  alarm_description         = "This metric monitors the up scaling of EC2s based on Discord requests vs running EC2."
  insufficient_data_actions = []
}

