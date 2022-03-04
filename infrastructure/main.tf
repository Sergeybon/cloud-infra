
data "terraform_remote_state" "glob" {
  backend = "s3"
  config = {
    bucket = "sbf-aws-terraform-state-backend"
    key    = "eu-central-1/glob/terraform.tfstate"
    region = "eu-central-1"
  }
}

data "terraform_remote_state" "prod" {
  backend = "s3"
  config = {
    bucket = "sbf-aws-terraform-state-backend"
    key    = "eu-central-1/prod/terraform.tfstate"
    region = "eu-central-1"
  }
}


resource "aws_cloudwatch_log_group" "frontend" {
  name              = "frontend"
  retention_in_days = 1
}

#resource "aws_ecs_task_definition" "frontend" {
#  family                = "frontend"
#  container_definitions = file("task-definition/frontend_task_defenition.json")
#
#}




###########################################
# New task definition
###########################################
resource "aws_ecs_task_definition" "frontend" {

  container_definitions = jsonencode([
    {
      name      = "frontend" //your na
      image     = "323957640402.dkr.ecr.eu-central-1.amazonaws.com/frontend:latest"
      essential = true
      cpu       = 0

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group = aws_cloudwatch_log_group.frontend.name
          awslogs-region = "eu-central-1"
        }

      }

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

#      environment: [
#        {
#          "name": "REACT_APP_BACKEND_HOSTNAME",
#          "value": "https://${backend_hostname}"
#        }
#      ],

      secrets = []
    }
  ])
  family                   = "frontend"
  cpu                      = 256
  #execution_role_arn       = ""
  memory                   = 256
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  #task_role_arn            = "ECSTaskRole"
}




#
#resource "aws_ecs_task_definition" "hello_world" {
#  family = "hello_world"
#
#  container_definitions = <<EOF
#[
#  {
#    "name": "hello_world",
#    "image": "hello-world",
#    "cpu": 0,
#    "memory": 128,
#    "logConfiguration": {
#      "logDriver": "awslogs",
#      "options": {
#        "awslogs-region": "eu-west-1",
#        "awslogs-group": "hello_world",
#        "awslogs-stream-prefix": "complete-ecs"
#      }
#    }
#  }
#]
#EOF
#}

resource "aws_ecs_service" "frontend" {
  name            = "frontend"
  cluster         = data.terraform_remote_state.prod.outputs.ecs_cluster_id_default
  task_definition = aws_ecs_task_definition.frontend.arn

  desired_count = 1

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

#  load_balancer {
#    target_group_arn = data.terraform_remote_state.glob.outputs.front_lb_target_group
#    container_name   = "hello_world"
#    container_port   = 80
#  }
}

output "test" {
  value = data.terraform_remote_state.prod.outputs.ecs_cluster_id_default
}