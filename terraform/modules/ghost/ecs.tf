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
