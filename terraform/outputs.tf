# Output EKS cluster endpoint
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

# Output EKS cluster security group ID
output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

# Output EKS cluster name
output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

# Output VPC ID
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

# Output private subnet IDs
output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

# Output public subnet IDs
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

# Output OIDC issuer URL
output "oidc_issuer_url" {
  description = "OIDC issuer URL for EKS cluster"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}