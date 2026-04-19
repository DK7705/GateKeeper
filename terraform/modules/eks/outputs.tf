# =============================================================================
# EKS Module Outputs
# =============================================================================

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = aws_security_group.cluster.id
}

output "node_group_arn" {
  description = "Node group ARN"
  value       = aws_eks_node_group.main.arn
}

output "cluster_certificate_authority" {
  description = "Cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}
