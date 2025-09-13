# VPC CIDR block variable
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# EKS cluster name variable
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "aminam-eks"
}

# AWS region variable
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}