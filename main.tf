terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}


provider "aws" {
  profile = "default"
  region  = "ap-northeast-1"
}

resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    "Name" = "${var.tag_prefix}-vpc"
  }
}

resource "aws_subnet" "pub_sbn" {
  count                   = var.resource_cnt
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)
  availability_zone       = var.az_list[count.index]
  map_public_ip_on_launch = true
  tags = {
    "Name" = "${var.tag_prefix}-pub-sbn-${var.az_num_list[count.index]}"
  }
}

resource "aws_subnet" "pvt_sbn" {
  count             = var.resource_cnt
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + length(aws_subnet.pub_sbn))
  availability_zone = var.az_list[count.index]
  tags = {
    "Name" = "${var.tag_prefix}-pvt-sbn-${var.az_num_list[count.index]}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.tag_prefix}-igw}"
  }
}


resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.tag_prefix}-rtb}"
  }
}

resource "aws_route" "pub" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.rtb.id
  gateway_id             = aws_internet_gateway.igw.id
}


resource "aws_route_table_association" "pub" {
  count          = var.resource_cnt
  subnet_id      = aws_subnet.pub_sbn[count.index].id
  route_table_id = aws_route_table.rtb.id

}


resource "aws_security_group" "sg" {

  name        = "allow_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.tag_prefix}-sg-ec2"
  }
}

resource "aws_security_group" "alb_sg" {

  name        = "alb_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.tag_prefix}-sg-alb"
  }
}

resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "allow_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.sg.id
}


resource "aws_security_group_rule" "alb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}



resource "aws_security_group_rule" "allow_outbound" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "alb_outbound" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}


resource "aws_instance" "ec2_pub" {

  count                       = var.resource_cnt
  ami                         = lookup(var.ec2_conf, "ami")
  instance_type               = lookup(var.ec2_conf, "instance_type")
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = aws_subnet.pub_sbn[count.index].id
  key_name                    = lookup(var.ec2_conf, "key_pair")
  associate_public_ip_address = "true"

  tags = {
    Name = "${var.tag_prefix}-ec2-pub-${count.index + 1}"
  }
}


resource "aws_alb" "alb" {
  name               = "${var.tag_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.pub_sbn.*.id

  tags = {
    Name = "${var.tag_prefix}-alb"
  }
}

resource "aws_lb_listener" "http_access" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name     = "${var.tag_prefix}-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
}


# tgにインスタンスを紐づける設定？っぽい
resource "aws_lb_target_group_attachment" "alb_tg_assoc" {
  count =  var.resource_cnt
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.ec2_pub[count.index].id
  port             = 80
}
