provider "aws" {
  version = "~> 2.62"
  region  = "eu-west-1"
  profile = "finstack"
}

provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  profile = "finstack"
}

terraform {
  required_version = "~> 0.12.0"
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "gregbkr"
    workspaces {
      name = "ghost-aws-ecs-dev"
    }
  }
}

variable "tag" {
  default = "blog-terra"
}
variable "instance_dns" {
  default = "ec2-3-249-228-52.eu-west-1.compute.amazonaws.com" # Get this var after a first deploy, when ECS is up, please replace then and terraform apply
}

module "ghost" {
  source = "../modules/ghost"
  # provider = "aws.eu-west-1"
  tag          = var.tag
  env          = "dev"
  dns_record   = "blog" # Leave empty for connecting to dns_domain directly
  dns_domain   = "mymicrosaving.com"
  cf_dns       = "blog.mymicrosaving.com"                                                              # The full DNS path of the blog
  cert_arn     = "arn:aws:acm:us-east-1:391378411314:certificate/be08f8a9-7c2e-404f-9fdb-159783313f57" # Your domain cert
  ami          = "ami-0a74b180a0c97ecd1"                                                               # Find the latest ami for https://aws.amazon.com/marketplace/pp/Amazon-Web-Services-Amazon-ECS-Optimized-Amazon-Li/B07KMLLN73?stl=true > continue to subscribe > find ami-id
  key_pair     = "aws-finstack-greg-user"
  subnets      = ["subnet-4756311d", "subnet-8efea4e8", "subnet-ca0e3b82"]
  instance_dns = var.instance_dns
}

# Healthcheck metric only works in us-east-1
module "healthcheck" {
  source = "../modules/healthcheck"
  providers = {
    aws = aws.us-east-1
  }
  tag          = var.tag
  instance_dns = var.instance_dns
}

# OUTPUTS
output "domain_name" {
  value = module.ghost.domain_name
}
output "efs_dns" {
  value = module.ghost.efs_dns
}

