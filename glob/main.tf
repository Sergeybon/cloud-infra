
locals {
  name   = "sbf"
  region = "eu-central-1"
  tags = {
    Environment = "glob"
    Name        = "sbf"
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

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source                 = "terraform-aws-modules/vpc/aws"
  version                = "3.7.0"
  name = local.name
  cidr                   = "10.10.0.0/16"
  azs                    = ["${local.region}a", "${local.region}b"]
  public_subnets         = ["10.10.21.0/24", "10.10.22.0/24"]
  private_subnets = ["10.10.23.0/24"]
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  tags = local.tags

}


####################
#ALB
####################

resource "aws_lb" "this" {
  name               = "${local.name}-alb"

  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id, aws_security_group.allow_tls.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false
}

resource "aws_lb_listener" "HTTP" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "redirect"
    redirect {
      port = "443"
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
#
#
#resource "aws_lb_listener" "HTTPS" {
#  load_balancer_arn = aws_lb.this.arn
#  port              = "443"
#  protocol          = "HTTPS"
#  ssl_policy        = "ELBSecurityPolicy-2016-08"
#  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn
#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.myec2.arn
#  }
#  depends_on = [aws_acm_certificate_validation.this]
#}



resource "aws_lb_target_group" "back" {
  name = "backend-target-group"
  #target_type = "ip"
  protocol = "HTTP"
  port = var.backend_port
  vpc_id      = module.vpc.vpc_id

}

resource "aws_lb_listener" "back_listener" {
  load_balancer_arn = aws_lb.this.arn
  port = 3000

  default_action {
    target_group_arn = aws_lb_target_group.back.arn
    type = "forward"
  }
}

resource "aws_lb_target_group" "front" {
  name        = "frontend-target-group"
  #target_type = "ip"
  protocol    = "HTTP"
  port = var.frontend_port
  vpc_id      = module.vpc.vpc_id
}

#
#resource "aws_lb_listener" "front_listener" {
#  load_balancer_arn = aws_lb.this.arn
#  port = 443
#  protocol = "HTTPS"
#  certificate_arn = var.cert_arn
#
#  default_action {
#    target_group_arn = aws_lb_target_group.front.arn
#    type = "forward"
#  }
#}






#resource "aws_lb_target_group_attachment" "targetgroup" {
#  target_group_arn = aws_lb_target_group.this.arn
#  target_id        = data.terraform_remote_state.prod.outputs.id
#  port             = 80
#}




#resource "aws_lb_target_group_attachment" "testterraform2" {
#  target_group_arn = aws_lb_target_group.myec2.arn
#  target_id        = aws_instance.test_instance2.id
#  port             = 80
#}

###############################
# SG
###############################


resource "aws_security_group" "vpc_tls" {
  name_prefix = "${local.name}-vpc_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  tags = local.tags
}


resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress = [
    {
      description      = "SSH from World"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
  egress = [
    {
      description      = "for all outgoing traffics"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]


  tags = {
    Name = "allow_ssh"
  }
}


resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow WEB inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress = [
    {
      description      = "WEB from World"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }

  ]
  egress = [
    {
      description      = "for all outgoing traffics"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]


  tags = {
    Name = "allow_web"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }
  #ipv6_cidr_block

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_security_group" "allow_elb" {
  name        = "allow_elb"
  description = "Allow ELB inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress = [
    {
      description      = "From ELB to EC2"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = [aws_security_group.allow_web.id]
      self             = false
    }
  ]
  egress = [
    {
      description      = "for all outgoing traffics"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]


  tags = {
    Name = "allow_elb"
  }
}
