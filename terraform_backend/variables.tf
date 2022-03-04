#variable "region" {
#  description = "AWS Region"
#  default     = "eu-central-1"
#}
#

variable "aws_region" {
  description = "AWS Region for the S3 and DynamoDB"
  default     = "eu-central-1"
}

variable "state_bucket" {
  description = "S3 bucket for holding Terraform state files. Must be globally unique."
  type        = string
  default     = "sbf-aws-terraform-state-backend"
}

variable "dynamodb_table" {
  description = "DynamoDB table for locking Terraform states"
  type        = string
  default     = "sbf-aws-terraform-state-locks"
}