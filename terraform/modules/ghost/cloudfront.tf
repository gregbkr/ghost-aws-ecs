# # Load balancer --> target group of ASG
# resource "aws_lb" "lb" {
#   name               = "lb-hello"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = ["${aws_security_group.ec2.id}"]
#   subnets            = "${data.aws_subnet_ids.default.ids}"
# }

# resource "aws_lb_listener" "http" {
#   load_balancer_arn = "${aws_lb.lb.arn}"
#   port              = "80"
#   protocol          = "HTTP"
#   default_action {
#     type             = "forward"
#     target_group_arn = "${aws_lb_target_group.tg.arn}"
#   }
# }

# CLOUDFRONT DISTRIBUTION
locals {
  s3_origin_id = var.tag
}
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = var.instance_dns
    origin_id   = local.s3_origin_id
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "My ghost blog"
  default_root_object = "/"
  aliases = ["${var.cf_dns}"]
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn = var.cert_arn
    ssl_support_method = "sni-only"
  }
}

# ROUTE53
data "aws_route53_zone" "main" {
  name = var.dns_domain
}
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.dns_record
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# HEALTHCHECK
# We will check instance DNS pourt 80 to see if VM/container did not go down
resource "aws_route53_health_check" "check" {
  fqdn              = var.instance_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "30"
  # regions           = ["${data.aws_region.current.name}"]
  cloudwatch_alarm_name   = aws_cloudwatch_metric_alarm.alarm.alarm_name
  cloudwatch_alarm_region = data.aws_region.current.name
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
}

resource "aws_sns_topic" "sns" {
  name = "${var.tag}-ecs-instance-dns-healthcheck-failed"
}
