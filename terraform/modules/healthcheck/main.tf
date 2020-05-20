variable "tag" {}
variable "instance_dns" {}

provider "aws" {
  region = "us-east-1"
}

resource "aws_route53_health_check" "check" {
  fqdn              = var.instance_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"
  cloudwatch_alarm_name   = aws_cloudwatch_metric_alarm.alarm.alarm_name
  cloudwatch_alarm_region = "us-east-1"
  tags = {
    Name = var.tag
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm" {
  alarm_name          = "${var.tag}-ecs-instance"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  datapoints_to_alarm = "1"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors ecs instance healthcheck"
  actions_enabled     = "true"
  alarm_actions       = [aws_sns_topic.sns.arn]
#   dimensions {
#     HealthCheckId = "${aws_route53_health_check.check.id}"
#   }
}

resource "aws_sns_topic" "sns" {
  name = "${var.tag}-ecs-instance-dns-healthcheck-failed"
}


# resource "aws_cloudwatch_metric_alarm" "metric_alarm" {
#   provider                  = "aws.use1"
#   alarm_name                = "${var.environment}-alarm-health-check"
#   comparison_operator       = "LessThanThreshold"
#   evaluation_periods        = "1"
#   metric_name               = "HealthCheckStatus"
#   namespace                 = "AWS/Route53"
#   period                    = "60"
#   statistic                 = "Minimum"
#   threshold                 = "1"
#   alarm_description         = "Send an alarm if ${var.environment} is down"
#   insufficient_data_actions = []

#   dimensions {
#     HealthCheckId = "${aws_route53_health_check.health_check.id}"
#   }
# }