
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


data "terraform_remote_state" "host" {
  backend = "s3"
  config = {
    bucket = "sbf-aws-terraform-state-backend"
    key    = "hosted-zone/terraform.tfstate"
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
  cidr                   = "20.10.0.0/16"
  azs                    = ["${local.region}a", "${local.region}b"]
  private_subnets     = ["20.10.1.0/24", "20.10.2.0/24"]
  public_subnets      = ["20.10.11.0/24", "20.10.12.0/24"]
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  tags = local.tags
  enable_dns_hostnames = true
  enable_dns_support = true
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


resource "aws_lb_listener" "HTTPS" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front.arn
  }
  depends_on = [aws_acm_certificate_validation.this]
}



resource "aws_lb_target_group" "back" {
  name = "backend-target-group"
  target_type = "ip"
  protocol = "HTTP"
  port = 3000
  vpc_id      = module.vpc.vpc_id
}

resource "aws_lb_listener" "back" {
  load_balancer_arn = aws_lb.this.arn
  port = 3000

  default_action {
    target_group_arn = aws_lb_target_group.back.arn
    type = "forward"
  }
}

resource "aws_lb_target_group" "front" {
  name        = "frontend-target-group"
  target_type = "ip"
  protocol    = "HTTP"
  port = 8080
  vpc_id      = module.vpc.vpc_id
}

resource "aws_lb_listener" "front" {
  load_balancer_arn =  aws_lb.this.arn
  port = 443
  protocol = "HTTPS"
  certificate_arn = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.front.arn
    type = "forward"
  }
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_lb_listener.front.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.back.arn
  }

  condition {
    path_pattern {
      values = ["/docs/"]
    }
  }

  condition {
    host_header {
      values = ["sbondar055.ga"]
    }
  }
}

resource "aws_lb_listener_rule" "back" {
  listener_arn = aws_lb_listener.front.arn
  priority     = 101

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.back.arn
  }

  condition {
    host_header {
      values = ["back.sbondar055.ga"]
    }
  }
}

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


resource "aws_security_group" "allow_ecs_sg" {
  name        = "allow_ecs_sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 80
    protocol  = "HTTP"
    to_port   = 80
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
  }

  tags = {
    Name = "allow_ecs"
  }
}

#########################
# bastion
#########################

#module "subnets" {
#  source               = "cloudposse/dynamic-subnets/aws"
#  version              = "0.39.3"
#  availability_zones   = ["${local.region}a", "${local.region}b"]
#  vpc_id               = module.vpc.vpc_id
#  igw_id               = module.vpc.igw_id
#  cidr_block           = "10.10.0.0/16"
#  nat_gateway_enabled  = false
#  nat_instance_enabled = false
#
#  context = module.this.context
#}
#
#module "aws_key_pair" {
#  source              = "cloudposse/key-pair/aws"
#  version             = "0.18.0"
#  attributes          = ["ssh", "key"]
#  ssh_public_key_path = var.ssh_key_path
#  generate_ssh_key    = var.generate_ssh_key
#
#  context = module.this.context
#}
#
#module "ec2_bastion" {
#  source = "..//modules/terraform-aws-ec2-bastion-server"
#
#  enabled = module.this.enabled
#
#  instance_type               = var.instance_type
#  security_groups             = [aws_security_group.allow_web.id, aws_security_group.allow_ssh.id]
#  subnets                     = module.vpc.public_subnets
#  key_name                    = module.aws_key_pair.key_name
#  user_data                   = var.user_data
#  vpc_id                      = module.vpc.vpc_id
#  associate_public_ip_address = var.associate_public_ip_address
#
#  context = module.this.context
#}

########################
# route53
########################
#
resource "aws_route53_record" "this" {
  zone_id = data.terraform_remote_state.host.outputs.zone_id_route53
  name    = "sbondar055.ga"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "back_record" {
  zone_id = data.terraform_remote_state.host.outputs.zone_id_route53
  name    = "back.sbondar055.ga"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

########################
# certificate
########################

# requests the certificate from Certificate Manager aws_acm_certificate
resource "aws_acm_certificate" "this" {
  domain_name       = "sbondar055.ga"
  subject_alternative_names = ["*.sbondar055.ga"]
  validation_method = "DNS"
}

resource "aws_route53_record" "this_dns_validation" {
  for_each = {
  for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
    name    = dvo.resource_record_name
    record  = dvo.resource_record_value
    type    = dvo.resource_record_type
    zone_id = dvo.domain_name == "sbondar055.ga" ? data.terraform_remote_state.host.outputs.zone_id_route53 : data.terraform_remote_state.host.outputs.zone_id_route53
  }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.this_dns_validation : record.fqdn]
  depends_on = [aws_route53_record.this_dns_validation]
}