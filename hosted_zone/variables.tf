
variable "region" {
  description = "AWS Region"
  default     = "eu-central-1"
}
#
#variable "frontend_port" {
#  description = "frontend port"
#  type = number
#  default = 8080
#}
#
#variable "backend_port" {
#  description = "backend port"
#  type = number
#  default = 3000
#}
#
#variable "availability_zones" {
#  description = "availability zones"
#}

#
#variable "site_domain" {
#  description = "site domain"
#  type = string
#}
#
#variable "cert_arn" {
#  type = string
#}

####################
# bastion
####################
#
#
#
#variable "instance_type" {
#  type        = string
#  default     = "t2.micro"
#  description = "Bastion instance type"
#}
#
#variable "user_data" {
#  type        = list(string)
#  default     = []
#  description = "User data content"
#}
#
#variable "ssh_key_path" {
#  type        = string
#  description = "Save location for ssh public keys generated by the module"
#}
#
#variable "generate_ssh_key" {
#  type        = bool
#  description = "Whether or not to generate an SSH key"
#}
#
#variable "security_groups" {
#  type        = list(string)
#  description = "List of Security Group IDs allowed to connect to the bastion host"
#}
#
#variable "root_block_device_encrypted" {
#  type        = bool
#  default     = false
#  description = "Whether to encrypt the root block device"
#}
#
#variable "root_block_device_volume_size" {
#  type        = number
#  default     = 8
#  description = "The volume size (in GiB) to provision for the root block device. It cannot be smaller than the AMI it refers to."
#}
#
#variable "metadata_http_endpoint_enabled" {
#  type        = bool
#  default     = true
#  description = "Whether the metadata service is available"
#}
#
#variable "metadata_http_put_response_hop_limit" {
#  type        = number
#  default     = 1
#  description = "The desired HTTP PUT response hop limit (between 1 and 64) for instance metadata requests."
#}
#
#variable "metadata_http_tokens_required" {
#  type        = bool
#  default     = false
#  description = "Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2."
#}
#
#variable "associate_public_ip_address" {
#  type        = bool
#  default     = true
#  description = "Whether to associate public IP to the instance."
#}