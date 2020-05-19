provider "aws" {
  region     = "eu-west-1"
}

# # Will we store our state in S3, and lock with dynamodb
# terraform {
#   backend "s3" {
#     # Replace this with your bucket name!
#     bucket         = "terraform-up-and-running-state-gg"
#     key            = "covid/prod/terraform.tfstate"
#     region         = "eu-west-3"
#     # Replace this with your DynamoDB table name!
#     dynamodb_table = "terraform-up-and-running-locks"
#     encrypt        = true
#   }
# }

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
  default = "ec2-3-250-122-215.eu-west-1.compute.amazonaws.com"
}
variable "subnets" {
  type    = list
  default = ["subnet-4756311d","subnet-8efea4e8","subnet-ca0e3b82"]
}

# LOOKUP DATA
data "aws_vpc" "default" {
  default = true
}
data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

# EFS
resource "aws_security_group" "efs" {
  name = "${var.tag}-efs"
  description = "Security Group"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_efs_file_system" "efs" {
  creation_token = var.tag
  tags = {
    Name = var.tag
  }
}
# Associate Firewall to our EFS
resource "aws_efs_mount_target" "a" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = var.subnets[0]
  security_groups = ["${aws_security_group.efs.id}"]
}
resource "aws_efs_mount_target" "b" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = var.subnets[1]
  security_groups = ["${aws_security_group.efs.id}"]
}
resource "aws_efs_mount_target" "c" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = var.subnets[2]
  security_groups = ["${aws_security_group.efs.id}"]
}

# EC2 linux instance to run ECS cluster. Needs ECS permission.
resource "aws_iam_role_policy" "policy" {
  name = "${var.tag}-policy"
  role = aws_iam_role.role.id
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "ec2:Describe*",
          "ecs:*",
          "logs:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}
# Policy to let session manager access our instance
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# EC2 instance role
resource "aws_iam_role" "role" {
  name = "${var.tag}-role"
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      },
      {
         "Effect":"Allow",
         "Principal":{
            "Service":"ssm.amazonaws.com"
         },
         "Action":"sts:AssumeRole"
      }
    ]
  }
  EOF
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.tag}-profile"
  role = aws_iam_role.role.name
}

# EC2
resource "aws_security_group" "firewall" {
  name = var.tag
  description = "Security Group"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # EFS port
  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${var.tag}-"
  image_id      = var.ami
  instance_type = "t2.micro"
  key_name      = "aws-finstack-greg-user"
  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }
  vpc_security_group_ids = ["${aws_security_group.firewall.id}"]
  user_data     = base64encode(<<EOF
    #!/bin/bash -xe
    echo ECS_CLUSTER=blog-terra >> /etc/ecs/ecs.config
  EOF
  )
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.tag}-ecs-instance-asg"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  name                      = "asg-${aws_launch_template.lt.name}"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  availability_zones        = ["eu-west-1a","eu-west-1b"]
  vpc_zone_identifier       = ["subnet-8efea4e8", "subnet-4756311d"]
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
#   target_group_arns         = ["${aws_lb_target_group.tg.arn}"]
  lifecycle {
    create_before_destroy = true
  }
}

# ECS
resource "aws_ecs_task_definition" "def" {
  family                = var.tag
  container_definitions = <<TASK_DEFINITION
  [
    {
        "cpu": 128,
        "environment": [
            {"name": "NODE_ENV", "value": "production"}
        ],
        "essential": true,
        "image": "ghost:0.11.3",
        "memory": 256,
        "name": "ghost",
        "portMappings": [
            {
                "containerPort": 2368,
                "hostPort": 80
            }
        ],
        "mountPoints": [
          {
            "sourceVolume": "efs",
            "containerPath": "/var/lib/ghost"
          }
        ]
    }
  ]
  TASK_DEFINITION
  volume {
    name = "efs"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs.id
      root_directory = "/"
    }
  }
}


resource "aws_ecs_cluster" "cluster" {
  name = var.tag
}

resource "aws_ecs_service" "service" {
  name            = var.tag
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.def.arn
  desired_count   = 1
}

# # Load balancer --> target group of ASG
# resource "aws_lb" "lb" {
#   name               = "lb-hello"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = ["${aws_security_group.firewall.id}"]
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
  aliases = ["${var.dns_name}"]
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

## ROUTE53
data "aws_route53_zone" "main" {
  name = var.dns_domain
}
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.dns_name
  type    = "A"

  alias {
    name                   =  aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

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
# output "my_instance_dns" {
#   value = data.aws_instance.i.public_dns
# }

output "first-subnets" {
  value = var.subnets[0]
}

