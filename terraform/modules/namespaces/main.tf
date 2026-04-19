# =============================================================================
# Kubernetes Namespaces Module
# Namespace-isolated environment with proper labels
# =============================================================================

resource "kubernetes_namespace" "app" {
  metadata {
    name = "secure-app"
    labels = {
      name        = "secure-app"
      environment = "production"
      managed-by  = "terraform"
      team        = "devsecops"
    }
    annotations = {
      "description" = "Application workloads namespace"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name        = "monitoring"
      environment = "production"
      managed-by  = "terraform"
      purpose     = "observability"
    }
    annotations = {
      "description" = "Prometheus, Grafana, ELK Stack monitoring namespace"
    }
  }
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
    labels = {
      name        = "logging"
      environment = "production"
      managed-by  = "terraform"
      purpose     = "log-aggregation"
    }
    annotations = {
      "description" = "ELK Stack log aggregation namespace"
    }
  }
}

output "namespace_names" {
  value = [
    kubernetes_namespace.app.metadata[0].name,
    kubernetes_namespace.monitoring.metadata[0].name,
    kubernetes_namespace.logging.metadata[0].name,
  ]
}
