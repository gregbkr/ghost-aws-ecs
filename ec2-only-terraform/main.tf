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
  default = "ghost-terra"
}
variable "ebs-id" {
  default = "vol-0a85b23a8069e39b5"
}
variable "dns_name" {
  default = "ghost.mymicrosaving.com"
}
variable "dns_domain" {
  default = "mymicrosaving.com"
}
variable "cert_arn" {
  default = "arn:aws:acm:us-east-1:391378411314:certificate/be08f8a9-7c2e-404f-9fdb-159783313f57"
}
# We will get this var after a first deploy, in the output, please replace then
variable "instance_dns" {
  default = "ec2-3-249-221-28.eu-west-1.compute.amazonaws.com"
}


# LOOKUP DATA
data "aws_vpc" "default" {
  default = true
}
data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_instance" "i" {
  instance_tags = {
    Name = "${var.tag}"
  }
}
# S3: GHOST DATA
resource "aws_s3_bucket" "b" {
  bucket = "${var.tag}-backup-gg"
  acl    = "private"
  tags = {
    Name        = var.tag
    Environment = "Master"
  }
}

resource "aws_s3_bucket_policy" "b" {
  bucket = aws_s3_bucket.b.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "${var.tag}-policy",
  "Statement": [
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ],
      "Resource": "${aws_s3_bucket.b.arn}"
    },
    {
      "Sid": "WriteToBucket",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.role.arn}"
      },
      "Action": "s3:*",
      "Resource": [
          "${aws_s3_bucket.b.arn}/*",
          "${aws_s3_bucket.b.arn}"
      ]
    }
  ]
}
POLICY
}

# EC2 IAM role
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
          "s3:List*",
          "s3:Get*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Action": [
          "s3:*"
        ],
        "Effect": "Allow",
        "Resource": [
          "${aws_s3_bucket.b.arn}/*",
          "${aws_s3_bucket.b.arn}"
        ]
      }
    ]
  }
  EOF
}
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
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${var.tag}-"
  image_id      = "ami-06ce3edf0cff21f07"
  instance_type = "t2.micro"
  key_name      = "aws-finstack-greg-user"
  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }
  vpc_security_group_ids = ["${aws_security_group.firewall.id}"]
  user_data     = "${base64encode(<<EOF
    #!/bin/bash -xe
    yum update -y 
    yum install -y docker
    systemctl start docker.service
    systemctl enable docker.service
    sudo gpasswd -a ec2-user docker
    whoami > README.md
    aws s3 cp s3://ghost-terra-backup-gg/ghost /ghost --recursive
    chown -R ec2-user:ec2-user /ghost
    chmod -R 755 /ghost
    echo "docker run -d -p 80:2368 -e NODE_ENV=production --name ghost -v /ghost:/var/lib/ghost ghost:0.11.3" > /ghost/README.md
    (crontab -l 2>/dev/null; echo "*/5 * * * * docker stop ghost && echo `date`: backup started >> /ghost/backup.log && aws s3 sync /ghost s3://ghost-terra-backup-gg/ghost --delete && docker start ghost") | crontab -
    docker run -d -p 80:2368 -e NODE_ENV=production --name ghost -v /ghost:/var/lib/ghost ghost:0.11.3
  EOF
  )}"
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = var.tag
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
  s3_origin_id = "S3-${var.tag}"
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

# ROUTE53
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
output "my_instance_dns" {
  value = data.aws_instance.i.public_dns
}
