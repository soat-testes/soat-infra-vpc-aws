variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_az_a" {
  type    = string
  default = "us-east-1a"
}

variable "aws_az_b" {
  type    = string
  default = "us-east-1b"
}

variable "ecr_image" { 
  type = string
  default = ""
}

variable "execution_role_ecs" { 
  type = string
  default = ""
}

variable "desired_tasks" { 
  type = number
  default = 1
}
