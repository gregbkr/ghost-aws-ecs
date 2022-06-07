# LOOKUP DATA
data "aws_vpc" "default" {
  default = true
}
# data "aws_subnet_ids" "default" {
#   vpc_id = "${data.aws_vpc.default.id}"
# }

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    #values = [var.vpc_id]
    values = ["${data.aws_vpc.default.id}"]
  }
}

data "aws_region" "current" {}