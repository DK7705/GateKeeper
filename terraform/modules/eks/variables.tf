# =============================================================================
# EKS Module Variables
# =============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the cluster"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "node_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
}

variable "node_desired_size" {
  description = "Desired worker node count"
  type        = number
}

variable "node_min_size" {
  description = "Minimum worker node count"
  type        = number
}

variable "node_max_size" {
  description = "Maximum worker node count"
  type        = number
}
