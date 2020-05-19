output "zone_id" {
  value = data.aws_route53_zone.main.zone_id
}
output "domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
output "hosted_zone_id" {
  value = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
}
output "default_vpc_id" {
  value = data.aws_vpc.default.id
}
output "default_subnet_ids" {
  value = ["${data.aws_subnet_ids.default.ids}"]
}
output "first-subnets" {
  value = var.subnets[0]
}
output "efs_dns" {
  value = aws_efs_file_system.efs.dns_name
}
# output "my_instance_dns" {
#   value = data.aws_instance.i.public_dns
# }

