# =============================================================================
# RBAC Module — Namespace-scoped, no cluster-admin for app accounts
# =============================================================================

variable "namespaces" {
  description = "List of namespace names"
  type        = list(string)
}

# App Service Account — scoped to secure-app namespace only
resource "kubernetes_service_account" "app" {
  metadata {
    name      = "app-service-account"
    namespace = "secure-app"
    annotations = {
      "description" = "Service account for application workloads"
    }
  }
  automount_service_account_token = false
}

# App Role — minimal permissions
resource "kubernetes_role" "app" {
  metadata {
    name      = "app-role"
    namespace = "secure-app"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "app" {
  metadata {
    name      = "app-role-binding"
    namespace = "secure-app"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.app.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.app.metadata[0].name
    namespace = "secure-app"
  }
}

# Deployer Service Account — for CI/CD pipeline
resource "kubernetes_service_account" "deployer" {
  metadata {
    name      = "deployer-service-account"
    namespace = "secure-app"
    annotations = {
      "description" = "Service account for CI/CD pipeline deployments"
    }
  }
  automount_service_account_token = false
}

# Deployer Role — deploy permissions only
resource "kubernetes_role" "deployer" {
  metadata {
    name      = "deployer-role"
    namespace = "secure-app"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log", "pods/exec"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding" "deployer" {
  metadata {
    name      = "deployer-role-binding"
    namespace = "secure-app"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.deployer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.deployer.metadata[0].name
    namespace = "secure-app"
  }
}

# Monitoring Service Account
resource "kubernetes_service_account" "monitoring" {
  metadata {
    name      = "monitoring-service-account"
    namespace = "monitoring"
    annotations = {
      "description" = "Service account for Prometheus and Grafana"
    }
  }
  automount_service_account_token = false
}

# Monitoring Role — read-only metrics access
resource "kubernetes_role" "monitoring" {
  metadata {
    name      = "monitoring-role"
    namespace = "monitoring"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "monitoring" {
  metadata {
    name      = "monitoring-role-binding"
    namespace = "monitoring"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.monitoring.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.monitoring.metadata[0].name
    namespace = "monitoring"
  }
}
