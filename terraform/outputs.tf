# =============================================================================
# Terraform Outputs
# =============================================================================

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_security_group_id" {
  description = "Security group ID for the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = module.eks.node_group_arn
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "namespace_names" {
  description = "List of created Kubernetes namespaces"
  value       = module.namespaces.namespace_names
}

# Dynamic Ansible inventory output
output "ansible_inventory" {
  description = "Dynamic inventory for Ansible in INI format"
  value = templatefile("${path.module}/templates/ansible-inventory.tpl", {
    cluster_endpoint = module.eks.cluster_endpoint
    cluster_name     = module.eks.cluster_name
    environment      = var.environment
    region           = var.aws_region
  })
}
