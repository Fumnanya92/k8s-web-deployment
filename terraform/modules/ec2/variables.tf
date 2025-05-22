
variable "vpc_id" {
  description = "VPC ID where the EC2 instance will be launched."
  type        = string
}


variable "security_group_id" {
  description = "Security group ID to attach to resources"
  type        = string
}

variable "subnet_id" {
    description = "Subnet ID to launch the instance in"
      type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "allocate_eip" {
  description = "Flag to allocate Elastic IP"
  type        = bool
  default     = true
}

