# VARIABLES
# Don't forget to replace S3 name in userdata!
variable "tag" {
  default = "blog-terra"
}
variable "dns_name" {
  default = "blog.mymicrosaving.com"
}
variable "dns_domain" {
  default = "mymicrosaving.com"
}
variable "cert_arn" {
  default = "arn:aws:acm:us-east-1:391378411314:certificate/be08f8a9-7c2e-404f-9fdb-159783313f57"
}
# Please find the latest ami for amzn-ami-2018.03.20200430-amazon-ecs-optimized in your region
variable "ami" {
  default = "ami-0a490cbd46f8461a9"
}
# We will get this var after a first deploy, when ECS is up, please replace then
variable "instance_dns" {
  default = "ec2-34-243-100-204.eu-west-1.compute.amazonaws.com"
}
variable "subnets" {
  type    = list
  default = ["subnet-4756311d","subnet-8efea4e8","subnet-ca0e3b82"]
}