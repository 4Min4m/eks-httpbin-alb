variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "etpa-eks"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "864981715490"
}