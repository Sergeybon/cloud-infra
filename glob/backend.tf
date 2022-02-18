terraform {
    backend "s3" {
      bucket         = "alvee-aws-terraform-state-backend"
      key            = "aws/us-east-1/development/glob/terraform.tfstate"
      region         = "us-east-1"
      dynamodb_table = "alvee-aws-terraform-state-locks"
      encrypt        = true
    }


}




terraform {
  required_version = ">= 0.13.1"
}

provider "aws" {
  region = var.region
}
