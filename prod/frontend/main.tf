
data "terraform_remote_state" "glob" {
  backend = "s3"
  config = {
    bucket = "sbf-aws-terraform-state-backend"
    key    = "eu-central-1/glob/terraform.tfstate"
    region = "eu-central-1"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "frontend"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "frontend" {
  family                = "frontend"
  container_definitions = file("task-definition/frontend_task_defenition.json")

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
  cluster         = var.cluster_id
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
