# =============================================================================
# Terraform Main Configuration
# Kubernetes cluster provisioning with security-first approach
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # Remote backend with S3 + DynamoDB state locking
  backend "s3" {
    bucket         = "secure-devops-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    kms_key_id     = "alias/terraform-state-key"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "SecureDevOps"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Team        = "DevSecOps"
    }
  }
}

# =============================================================================
# Modules
# =============================================================================

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  environment        = var.environment
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

module "namespaces" {
  source = "./modules/namespaces"

  depends_on = [module.eks]
}

module "rbac" {
  source = "./modules/rbac"

  namespaces = module.namespaces.namespace_names
  depends_on = [module.namespaces]
}

module "network_policies" {
  source = "./modules/network-policies"

  namespaces = module.namespaces.namespace_names
  depends_on = [module.namespaces]
}
