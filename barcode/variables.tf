variable "vpc_cidr" {
  description = "VPC CIDR Range"
  type = string
}

variable "subnet_cidr" {
    description = "Subnet CIDRS"
    type = list(string)
}

variable "aws_region" {
    description = "aws_region"
    type = string
}

variable "project_name" {
    description = "project_name"
    type = string
}

variable "environment" {
    description = "environment"
    type = string
}