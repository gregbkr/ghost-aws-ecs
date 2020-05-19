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
resource "aws_security_group" "ec2" {
  name = "${var.tag}-ec2"
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
  # Session manager?
  ingress {
    from_port = 443
    to_port = 443
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
  vpc_security_group_ids = ["${aws_security_group.ec2.id}"]
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