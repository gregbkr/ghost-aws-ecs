provider "aws" {
  version = "~> 2.62"
  region = "eu-west-1"
  profile = "gregbkr"
}

terraform {
  required_version = "~> 0.12.0"
  backend "remote" {  
    hostname = "app.terraform.io"
    organization = "gregbkr"
    workspaces {
      name = "ghost-aws-ecs-prod"
    }
  }
}

module "ghost" {
  source = "../modules/ghost"
  tag = "ghost-blog"
  dns_record = "" # Leave empty for connecting to dns_domain directly
  dns_domain = "d3vblog.com"
  cf_dns = "d3vblog.com" # The full DNS path of the blog
  cert_arn = "arn:aws:acm:us-east-1:282835178041:certificate/5aaffe3b-aff7-42a7-8297-182926345bc0" # Your domain cert
  ami = "ami-0a490cbd46f8461a9" # Find the latest ami for amzn-ami-2018.03.20200430-amazon-ecs-optimized in your region
  key_pair = "greg-eu-west-1"
  subnets = ["subnet-390a8063","subnet-8c430bea","subnet-c2ca928a"]
  instance_dns = "ec2-34-243-100-167.eu-west-1.compute.amazonaws.com" # Get this var after a first deploy, when ECS is up, please replace then and terraform apply
}

# OUTPUTS
output "domain_name" {
  value = module.ghost.domain_name
}
output "efs_dns" {
  value = module.ghost.efs_dns
}
