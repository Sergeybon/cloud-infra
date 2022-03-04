#terraform {
#    backend "s3" {
#      bucket         = "sbf-aws-terraform-state-backend"
#      key            = "terraform-backend/terraform.tfstate"
#      region         = "eu-central-1"
#      dynamodb_table = "sbf-aws-terraform-state-locks"
#      encrypt        = true
#    }
#
#  required_providers {
#    aws = {
#      source  = "hashicorp/aws"
#      version = "4.2.0"
#
#    }
#  }
#
#}
#
#
#
#
#terraform {
#  required_version = ">= 0.13.1"
#}
#
#provider "aws" {
#  region = var.region
#}
