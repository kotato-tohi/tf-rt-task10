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

# --------------------------------------------#
# ec2 security group
# --------------------------------------------#

resource "aws_security_group" "ec2_sg" {

  name        = "ec2_sg"
  description = "Allow inbound traffic ec2"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.tag_prefix}-sg-ec2"
  }
}

resource "aws_security_group_rule" "ec2_ssh" {
  description       = "Allow ssh traffic from internet"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_sg.id
}


resource "aws_security_group_rule" "allow_http" {
  description              = "Allow http traffic from alb"
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.ec2_sg.id
}

# --------------------------------------------#
# alb security group
# --------------------------------------------#


resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow inbound traffic alb"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "${var.tag_prefix}-sg-alb"
  }
}

resource "aws_security_group_rule" "alb_http" {
  description       = "Allow http traffic from internet"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_https" {
  description       = "Allow https traffic from internet"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}


# --------------------------------------------#
# rds security group
# --------------------------------------------#

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow inbound traffic rds"
  vpc_id      = aws_vpc.vpc.id
  tags = {
    Name = "${var.tag_prefix}-sg-rds"
  }
}

resource "aws_security_group_rule" "rds_mysql" {
  description              = "Allow mysql traffic from ec2_sg"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_sg.id
  security_group_id        = aws_security_group.rds_sg.id
}




# --------------------------------------------#
# security group outbound allow rules
# --------------------------------------------#



resource "aws_security_group_rule" "allow_outbound" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_security_group_rule" "alb_outbound" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "rds_outbound" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_sg.id
}


# --------------------------------------------#
# ec2 instance
# --------------------------------------------#

resource "aws_instance" "ec2" {

  count                       = var.resource_cnt
  ami                         = lookup(var.ec2_conf, "ami")
  instance_type               = lookup(var.ec2_conf, "instance_type")
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
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

resource "aws_lb_listener" "https_access" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_arn
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
  count            = var.resource_cnt
  target_group_arn = aws_lb_target_group.alb_tg.arn
  target_id        = aws_instance.ec2[count.index].id
  port             = 80
}


resource "aws_db_subnet_group" "rds-sbn-gp" {
  name       = "rds-sbn-gp"
  subnet_ids = aws_subnet.pvt_sbn.*.id

  tags = {
    Name = "rds-sbn-gp"
  }
}

resource "aws_db_instance" "rds" {

  depends_on = [
    aws_security_group.rds_sg
  ]

  allocated_storage      = lookup(var.rds_conf, "allocated_storage")
  engine                 = lookup(var.rds_conf, "engine")
  engine_version         = lookup(var.rds_conf, "engine_version")
  instance_class         = lookup(var.rds_conf, "instance_class")
  name                   = lookup(var.rds_conf, "name")
  username               = lookup(var.rds_conf, "master_name")
  password               = lookup(var.rds_conf, "master_pass")
  parameter_group_name   = lookup(var.rds_conf, "parameter_group_name")
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.rds-sbn-gp.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}


resource "aws_s3_bucket" "bucket1" {
  bucket = "${var.tag_prefix}-bucket-1"
  acl    = "private"

  tags = {
    Name        = "${var.tag_prefix}-bucket-1"
  }
}