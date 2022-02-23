
variable "region" {
  description = "AWS Region"
  default     = "eu-central-1"
}

variable "frontend_port" {
  description = "frontend port"
  type = number
  default = 8080
}

variable "backend_port" {
  description = "backend port"
  type = number
  default = 3000
}
#
#variable "site_domain" {
#  description = "site domain"
#  type = string
#}
#
#variable "cert_arn" {
#  type = string
#}
