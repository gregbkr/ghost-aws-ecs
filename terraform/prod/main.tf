provider "aws" {
  #version = "~> 2.62"
  region = "eu-west-1"
  profile = "gregbkr"
}

provider "aws" {
  alias  = "healthcheck"
  region = "us-east-1"
  profile = "gregbkr"
}

terraform {
  required_version = "~> 1.2.1"
  backend "remote" {  
    hostname = "app.terraform.io"
    organization = "gregbkr"
    workspaces {
      name = "ghost-aws-ecs-prod"
    }
  }
}

variable "tag" {
  default = "ghost-blog-prod"
}
variable "instance_dns" {
  default = "ec2-54-216-241-241.eu-west-1.compute.amazonaws.com" # Get this var after a first deploy, when ECS is up, please replace then and terraform apply
}

module "ghost" {
  source        = "../modules/ghost"
  tag           = var.tag
  env           = "production"
  dns_record    = "greg" # Leave empty for connecting to dns_domain directly
  dns_domain    = "satoshi.tech"
  cf_dns        = "greg.satoshi.tech" # The full DNS path of the blog
  cert_arn      = "arn:aws:acm:us-east-1:282835178041:certificate/e34fadff-b0d8-47d4-978f-58bd41b6194a" # Your domain cert
  ami           = "ami-07a1802c113adc855" # Find the latest ami for https://aws.amazon.com/marketplace/pp/Amazon-Web-Services-Amazon-ECS-Optimized-Amazon-Li/B07KMLLN73?stl=true > continue to subscribe > find ami-id
  key_pair      = "gregbk1@laptopasus"
  subnets       = ["subnet-390a8063","subnet-8c430bea","subnet-c2ca928a"]
  instance_dns  = var.instance_dns
}

# Healthcheck metric only works in us-east-1
module "healthcheck" { 
  source = "../modules/healthcheck"
  providers = {
    aws = aws.healthcheck
  }
  tag = var.tag
  instance_dns = var.instance_dns
}

# OUTPUTS
output "domain_name" {
  value = module.ghost.domain_name
}
output "efs_dns" {
  value = module.ghost.efs_dns
}
