resource "vpc" "this" {
  cidr_block = "10.8.0.0/16"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "new-public-01" {
  vpc_id                  = vpc.this.id
  cidr_block              = "10.8.128.0/18"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "new-public-01"
  }
}

resource "aws_subnet" "new-public-02" {
  vpc_id                  = vpc.this.id
  cidr_block              = "10.8.192.0/18"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "new-public-02"
  }
}


resource "aws_internet_gateway" "myigw" {
  vpc_id = vpc.this.id

  tags = {
    Name = "myigw"
  }
}

resource "aws_route_table" "default_rt" {
  vpc_id = vpc.this.id

  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      gateway_id                 = aws_internet_gateway.myigw.id
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      nat_gateway_id             = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    }
  ]

  tags = {
    Name = "myroutetable"
  }
}

resource "aws_main_route_table_association" "a" {
  vpc_id         = vpc.this.id
  route_table_id = aws_route_table.default_rt.id
}

####################
#ALB
####################

resource "aws_lb" "this" {
  name               = "testterraformlb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id, aws_security_group.allow_tls.id]
  subnets            = [aws_subnet.new-public-01.id, aws_subnet.new-public-02.id]

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
    target_group_arn = aws_lb_target_group.myec2.arn
  }
  depends_on = [aws_acm_certificate_validation.this]
}

resource "aws_lb_target_group" "myec2" {
  name        = "testterraform"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = vpc.this.id
}

resource "aws_lb_target_group_attachment" "testterraform" {
  target_group_arn = aws_lb_target_group.myec2.arn
  target_id        = aws_instance.test_instance.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "testterraform2" {
  target_group_arn = aws_lb_target_group.myec2.arn
  target_id        = aws_instance.test_instance2.id
  port             = 80
}