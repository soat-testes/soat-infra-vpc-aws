provider "aws" {
  region = var.aws_region
}

### VPC CONFIG ###

resource "aws_vpc" "vpc_soat" {
  cidr_block           = "10.0.0.0/23"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name  = "vpc-soat"
    infra = "vpc-soat"
  }
}

output "vpc_soat_id" {
  value = aws_vpc.vpc_soat.id
}

resource "aws_route_table" "route_table_a" {
  vpc_id = aws_vpc.vpc_soat.id
}

resource "aws_route_table" "route_table_b" {
  vpc_id = aws_vpc.vpc_soat.id
}

resource "aws_subnet" "soat_subnet_private1_us_east_1a" {
  vpc_id                  = aws_vpc.vpc_soat.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = var.aws_az_a
  map_public_ip_on_launch = false
  tags = {
    Name  = "soat-subnet-private1-us-east-1a"
    infra = "vpc-soat"
  }
}

output "subnet_a_id" {
  value = aws_subnet.soat_subnet_private1_us_east_1a.id
}

resource "aws_route_table_association" "subnet_association_a" {
  subnet_id      = aws_subnet.soat_subnet_private1_us_east_1a.id
  route_table_id = aws_route_table.route_table_a.id
}

output "route_table_a" {
  value = aws_route_table_association.subnet_association_a.id
}

resource "aws_subnet" "soat_subnet_private1_us_east_1b" {
  vpc_id                  = aws_vpc.vpc_soat.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.aws_az_b
  map_public_ip_on_launch = false
  tags = {
    Name  = "soat-subnet-private1-us-east-1b"
    infra = "vpc-soat"
  }
}

output "subnet_b_id" {
  value = aws_subnet.soat_subnet_private1_us_east_1b.id
}

resource "aws_route_table_association" "subnet_association_b" {
  subnet_id      = aws_subnet.soat_subnet_private1_us_east_1b.id
  route_table_id = aws_route_table.route_table_b.id
}

output "route_table_b" {
  value = aws_route_table_association.subnet_association_b.id
}

resource "aws_security_group" "security_group_load_balancer" {
  name_prefix = "security-group-load-balancer"
  description = "load balancer SG"
  vpc_id      = aws_vpc.vpc_soat.id

  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_security_group" "security_group_cluster_ecs" {
  name_prefix = "security-group-cluster-ecs"
  description = "cluster ecs SG"
  vpc_id      = aws_vpc.vpc_soat.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.security_group_load_balancer.id]
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

output "security_group_ecs_id" {
  value = aws_security_group.security_group_cluster_ecs.id
}

resource "aws_security_group_rule" "security_group_cluster_ecs_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.security_group_cluster_ecs.id
  depends_on        = [aws_ecs_cluster.cluster_ecs_soat]
}



### Target Group + Load Balancer

resource "aws_lb_target_group" "target_group_soat_api" {
  depends_on = [ aws_vpc.vpc_soat ]
  name        = "tg-soat-api"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc_soat.id

  health_check {
    enabled             = true
    interval            = 30
    matcher             = "200-299"
    path                = "/health_check"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = {
    infra = "tg-soat-api"
  }
}

output "target_group_soat_api_arn" {
  value = aws_lb_target_group.target_group_soat_api.arn
}

resource "aws_lb" "alb_soat_api" {
  name               = "alb-soat-api"
  internal           = true
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [aws_security_group.security_group_load_balancer.id]
  subnets = [
    aws_subnet.soat_subnet_private1_us_east_1a.id,
    aws_subnet.soat_subnet_private1_us_east_1b.id
  ]

  tags = {
    infra = "alb-soat-api"
  }
}

resource "aws_lb_listener" "alb_soat_listener" {
  load_balancer_arn = aws_lb.alb_soat_api.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_soat_api.arn
  }

  tags = {
    Name  = "alb-soat-listener"
    infra = "alb-soat-listener"
  }

}

### ECS CONFIG ###

resource "aws_ecs_cluster" "cluster_ecs_soat" {
  name = "cluster-ecs-soat"

  tags = {
    infra = "cluster-ecs-soat"
  }
}

output "cluster_ecs_soat_id" {
  value = aws_ecs_cluster.cluster_ecs_soat.id
}

resource "aws_ecs_task_definition" "task_definition_ecs" {
  family                   = "task-definition-family-01"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = var.execution_role_ecs

  cpu    = 512
  memory = 1024
  container_definitions = jsonencode([
    {
      name      = "container-1"
      image     = var.ecr_image
      cpu       = 256,
      memory    = 256,
      essential = true,
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = {
    infra = "task-definition-ecs"
  }
}

output "task_definition_ecs_arn" {
  value = aws_ecs_task_definition.task_definition_ecs.arn
}
