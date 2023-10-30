provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "vpc-soat" {
  cidr_block           = "10.0.0.0/26"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name  = "vpc-soat"
    infra = "vpc-soat"
  }
}

resource "aws_subnet" "soat-subnet-private1-us-east-1a" {
  vpc_id                  = aws_vpc.vpc-soat.id
  cidr_block              = "10.0.0.0/28"
  availability_zone       = var.aws_az_a
  map_public_ip_on_launch = false
  tags = {
    Name  = "soat-subnet-private1-us-east-1a"
    infra = "vpc-soat"
  }
}

resource "aws_subnet" "soat-subnet-private1-us-east-1b" {
  vpc_id                  = aws_vpc.vpc-soat.id
  cidr_block              = "10.0.0.16/28"
  availability_zone       = var.aws_az_a
  map_public_ip_on_launch = false
  tags = {
    Name  = "soat-subnet-private1-us-east-1b"
    infra = "vpc-soat"
  }
}

resource "aws_security_group" "security-group-load-balancer" {
  name_prefix = "security-group-load-balancer"
  description = "load balancer SG"
  vpc_id      = aws_vpc.vpc-soat.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    infra = "vpc-soat"
    Name  = "security-group-load-balancer"
  }
}

resource "aws_security_group" "security-group-cluster-ecs" {
  name_prefix = "security-group-cluster-ecs"
  description = "cluster ecs SG"
  vpc_id      = aws_vpc.vpc-soat.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.security-group-load-balancer.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    infra = "vpc-soat"
    Name  = "security-group-cluster-ecs"
  }
}
