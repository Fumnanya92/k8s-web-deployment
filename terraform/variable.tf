variable "aws_region" {
  type = string
    default = "us-west-2"
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"  
}

variable "public_subnet_1_cidr" {
  type = string
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  type = string
  default = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  type = string
  default = "10.0.3.0/24"
}

variable "private_subnet_2_cidr" {
  type = string
  default = "10.0.4.0/24"         
}

variable "availability_zone_1" {
  type = string
    default = "us-west-2a"
}

variable "availability_zone_2" {
  type = string
  default = "us-west-2b"
}
variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
    default     = "k8s"
}

variable "security_group_id" {
  description = "Security group ID to attach to resources"
  type        = string
  default     = "k8s_sg"
}

variable "environment" {
  description = "Environment tag (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}