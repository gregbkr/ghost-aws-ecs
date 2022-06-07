variable "tag" {}
variable "instance_dns" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      #version = ">= 2.7.0"
    }
  }
}

resource "aws_route53_health_check" "check" {
  fqdn              = var.instance_dns
  port              = 2368
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"
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
  dimensions = {
    HealthCheckId = "${aws_route53_health_check.check.id}"
  }
}

resource "aws_sns_topic" "sns" {
  name = "${var.tag}-ecs-instance-dns-healthcheck-failed"
}
