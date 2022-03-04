
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

#
#data "terraform_remote_state" "terraform-backend" {
#  backend = "s3"
#  config = {
#    bucket = "sbf-aws-terraform-state-backend"
#    key    = "terraform-backend.tfstate"
#    region = "eu-central-1"
#  }
#}

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
#resource "aws_route53_record" "a_record" {
#  zone_id = data.terraform_remote_state.prod.outputs.ecs_cluster_id_default.aws_route53_zone.zone.zone_id
#  # zone_id = aws_route53_zone.route53_zone.zone_id
#  count = local.workspace == "prod" ? 1 : 0
#  name    = var.site_domain
#  type    = "A"
#
#  alias {
#    name                   = var.load_balancer_name
#    zone_id                = var.load_balancer_zone_id
#    evaluate_target_health = true
#  }
#}
#
#resource "aws_route53_record" "workspace_record" {
#  zone_id = data.aws_route53_zone.zone.zone_id
#  name    = "${local.workspace}.${var.site_domain}"
#  type    = "A"
#  count = local.workspace == "prod" ? 0 : 1
#
#  alias {
#    name                   = var.load_balancer_name
#    zone_id                = var.load_balancer_zone_id
#    evaluate_target_health = true
#  }
#}
#
#resource "aws_route53_record" "api_record" {
#  zone_id = data.aws_route53_zone.zone.zone_id
#  name    = "api.${var.site_domain}"
#  type    = "A"
#  count = local.workspace == "prod" ? 1 : 0
#
#  alias {
#    name                   = var.load_balancer_name
#    zone_id                = var.load_balancer_zone_id
#    evaluate_target_health = true
#  }
#}
#
#resource "aws_route53_record" "api_workspace_record" {
#  zone_id = data.aws_route53_zone.zone.zone_id
#  name    = "api-${local.workspace}.${var.site_domain}"
#  type    = "A"
#  count = local.workspace == "prod" ? 0 : 1
#
#  alias {
#    name                   = var.load_balancer_name
#    zone_id                = var.load_balancer_zone_id
#    evaluate_target_health = true
#  }
#}
#
#resource "aws_route53_record" "www_record" {
#  zone_id = data.aws_route53_zone.zone.zone_id
#  name    = "www"
#  type    = "CNAME"
#  ttl     = "5"
#  records = [var.site_domain]
#  count = local.workspace == "prod" ? 1 : 0
#}
#
##_______
#
#resource "aws_acm_certificate" "cert" {
#  domain_name       = var.site_domain
#  subject_alternative_names = ["*.${var.site_domain}"]
#  validation_method = "DNS"
#}
#
#resource "aws_route53_record" "example" {
#  for_each = {
#  for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
#    name    = dvo.resource_record_name
#    record  = dvo.resource_record_value
#    type    = dvo.resource_record_type
#    zone_id = dvo.domain_name == var.site_domain ? data.aws_route53_zone.zone.zone_id : data.aws_route53_zone.zone.zone_id
#  }
#  }
#
#  allow_overwrite = true
#  name            = each.value.name
#  records         = [each.value.record]
#  ttl             = 60
#  type            = each.value.type
#  zone_id         = each.value.zone_id
#}
#
#resource "aws_acm_certificate_validation" "example" {
#  certificate_arn         = aws_acm_certificate.cert.arn
#  validation_record_fqdns = [for record in aws_route53_record.example : record.fqdn]
#}
