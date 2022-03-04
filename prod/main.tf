locals {
  name        = "sbf"
#  cluster_name = "ecs"
  environment = terraform.workspace

  # This is the convention we use to know what belongs to each other
  ec2_resources_name = "${local.name}-${local.environment}"
}
data "terraform_remote_state" "glob" {
  backend = "s3"
  config = {
    bucket = "sbf-aws-terraform-state-backend"
    key    = "eu-central-1/glob/terraform.tfstate"
    region = "eu-central-1"
  }
}


######################
# ECR
######################

resource "aws_ecr_repository" "frontend" {
  name = "frontend"

  tags = {
    "Name" = "Frontend"
    "Environment" = local.environment
  }
}

resource "aws_ecr_lifecycle_policy" "frontendpolicy" {
  repository = aws_ecr_repository.frontend.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_ecr_lifecycle_policy" "backendpolicy" {
  repository = aws_ecr_repository.backend.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "aws_ecr_repository" "backend" {
  name = "backend"

  tags = {
    "Name" = "Backend"
    "Environment" = local.environment
  }
}


#----- ECS --------




module "ecs" {
  source = "../modules/terraform-aws-ecs"

  name               = local.name
  container_insights = true

#  capacity_providers = [aws_ecs_capacity_provider.prov1.name]

#  default_capacity_provider_strategy = [{
#    capacity_provider = aws_ecs_capacity_provider.prov1.name # "FARGATE_SPOT"
#    weight            = "1"
#  }]

  tags = {
    Environment = local.environment
  }
}
#
#resource "aws_ecs_cluster" "ecs_cluster" {
#  name = local.name
#}


#
#module "ec2_profile" {
#  source = "../modules/terraform-aws-ecs/modules/ecs-instance-profile"
#
#  name = local.name
#
#  tags = {
#    Environment = local.environment
#  }
#}
#
#resource "aws_ecs_capacity_provider" "prov1" {
#  name = "prov1"
#
#  auto_scaling_group_provider {
#    auto_scaling_group_arn = module.asg.autoscaling_group_arn
#  }
#
#}

#----- ECS  Resources--------

#For now we only use the AWS ECS optimized ami <https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html>
data "aws_ami" "amazon_linux_ecs" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}
#
#module "asg" {
#  source  = "terraform-aws-modules/autoscaling/aws"
#  version = "~> 4.0"
#
#  name = local.ec2_resources_name
#
##  # Launch configuration
##  lc_name   = local.ec2_resources_name
##  use_lc    = true
##  create_lc = true
##
##  image_id                  = data.aws_ami.amazon_linux_ecs.id
##  instance_type             = "t2.micro"
##  security_groups           = [data.terraform_remote_state.glob.outputs.allow_ecs_sg]
##  iam_instance_profile_name = module.ec2_profile.iam_instance_profile_id
##  user_data = templatefile("${path.module}/templates/user-data.sh", {
##    cluster_name = local.name
##  })
#
#  # Auto scaling group
#  vpc_zone_identifier       = data.terraform_remote_state.glob.outputs.private_subnets
##  health_check_type         = "EC2"
#  min_size                  = 1
#  max_size                  = 2
#  desired_capacity          = 1 # we don't need them for the example
##  wait_for_capacity_timeout = 0
#  launch_configuration = aws_launch_configuration.new_launch_configuration.name
#
#  tags = [
#    {
#      key                 = "Environment"
#      value               = local.environment
#      propagate_at_launch = true
#    },
#    {
#      key                 = "Cluster"
#      value               = local.name
#      propagate_at_launch = true
#    },
#  ]
#}

resource "aws_autoscaling_group" "new_asg" {
  name                 = "${local.name}-autoscaling-group"
  vpc_zone_identifier       = data.terraform_remote_state.glob.outputs.private_subnets
  max_size             = 2
  min_size             = 1
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.new_launch_configuration.name
#  availability_zones   = data.terraform_remote_state.glob.outputs.azs
}


resource "aws_launch_configuration" "new_launch_configuration" {
  name                        = local.ec2_resources_name
  associate_public_ip_address = true
  image_id                    = data.aws_ami.amazon_linux_ecs.id
  iam_instance_profile        = aws_iam_instance_profile.ecs_agent.name
  instance_type               = "t2.medium"
  security_groups             = [aws_security_group.allow_ecs_sg2.id]
  user_data                   = <<EOT
    #!/bin/bash
    echo ECS_CLUSTER=${local.name} >> /etc/ecs/ecs.config
  EOT
}


resource "aws_security_group" "allow_ecs_sg2" {
  name        = "allow_ecs_sg2"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.terraform_remote_state.glob.outputs.vpc_id

  ingress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ecs2"
  }
}



resource "aws_iam_role" "ecs_agent" {
  name               = "${local.ec2_resources_name}-ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "${local.ec2_resources_name}-ecs-agent"
  role = aws_iam_role.ecs_agent.name
}


data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

##################
# Disabled cluster
##################
#
#module "disabled_ecs" {
#  source = "../modules/terraform-aws-ecs"
#
#  create_ecs = false
#}
#


##########################
# Ewndpoints
##########################
#resource "aws_vpc_endpoint" "ecs-agent" {
#  service_name = "com.amazonaws.eu-central-1.ecs-agent"
#  vpc_id       = data.terraform_remote_state.glob.outputs.vpc_id
#  vpc_endpoint_type = "Interface"
#  private_dns_enabled = true
#  security_group_ids = [aws_security_group.endpoint_sg.id]
#}
#resource "aws_vpc_endpoint" "ecs-telemetry" {
#  service_name = "com.amazonaws.eu-central-1.ecs-telemetry"
#  vpc_id = data.terraform_remote_state.glob.outputs.vpc_id
#  vpc_endpoint_type = "Interface"
#  private_dns_enabled = true
#  security_group_ids = [aws_security_group.endpoint_sg.id]
#}
#resource "aws_vpc_endpoint" "ecs" {
#  service_name = "com.amazonaws.eu-central-1.ecs"
#  vpc_id       = data.terraform_remote_state.glob.outputs.vpc_id
#  vpc_endpoint_type = "Interface"
#  private_dns_enabled = true
#  security_group_ids = [aws_security_group.endpoint_sg.id]
#}
#resource "aws_security_group" "endpoint_sg" {
#  vpc_id = data.terraform_remote_state.glob.outputs.vpc_id
#  ingress {
#    from_port = 0
#    protocol  = "-1"
#    to_port   = 0
#    cidr_blocks = [data.terraform_remote_state.glob.outputs.vpc_cidr_block]
#  }
#  egress {
#    from_port = 0
#    protocol  = "-1"
#    to_port   = 0
#    cidr_blocks = [data.terraform_remote_state.glob.outputs.vpc_cidr_block]
#  }
#}