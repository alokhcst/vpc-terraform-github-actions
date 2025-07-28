terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.16.1"
    }
  }

  backend "s3" {
    bucket = "s3terraformvpc"
    key    = "dev/terraform.tfstate"
    region = "us-east-2"
  }
}

provider "aws" {
  region = "us-east-2"
}
