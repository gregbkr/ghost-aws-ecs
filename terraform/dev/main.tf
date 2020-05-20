provider "aws" {
  version = "~> 2.62"
  region = "eu-west-1"
  profile = "finstack"
}

terraform {
  required_version = "~> 0.12.0"
  backend "remote" {  
    hostname = "app.terraform.io"
    organization = "gregbkr"
    workspaces {
      name = "ghost-aws-ecs-dev"
    }
  }
}

module "ghost" {
  source = "../modules/ghost"
  tag = "blog-terra"
  dns_record = "blog" # Leave empty for connecting to dns_domain directly
  dns_domain = "mymicrosaving.com"
  cf_dns = "blog.mymicrosaving.com" # The full DNS path of the blog
  cert_arn = "arn:aws:acm:us-east-1:391378411314:certificate/be08f8a9-7c2e-404f-9fdb-159783313f57" # Your domain cert
  ami = "ami-0a490cbd46f8461a9" # Find the latest ami for amzn-ami-2018.03.20200430-amazon-ecs-optimized in your region
  key_pair = "aws-finstack-greg-user"
  subnets = ["subnet-4756311d","subnet-8efea4e8","subnet-ca0e3b82"]
  instance_dns = "ec2-52-209-82-50.eu-west-1.compute.amazonaws.com" # Get this var after a first deploy, when ECS is up, please replace then and terraform apply
}

# module "healthcheck" {
#   source = "../modules/healthcheck"
#   tag = "blog-terra"
#   instance_dns = "ec2-52-209-82-50.eu-west-1.compute.amazonaws.com" # Get this var after a first deploy, when ECS is up, please replace then and terraform apply
# }

# OUTPUTS
output "domain_name" {
  value = module.ghost.domain_name
}
output "efs_dns" {
  value = module.ghost.efs_dns
}

