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
    count = 2
    vpc_id = aws_vpc.vpc.id
    cidr_block = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)
    availability_zone = var.az_list[count.index]
    tags = {
        "Name" = "${var.tag_prefix}-pub-sbn-${var.az_num_list[count.index]}}"
    }
}