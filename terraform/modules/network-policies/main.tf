# =============================================================================
# Network Policies Module — Least-privilege pod communication
# =============================================================================

variable "namespaces" {
  description = "List of namespace names"
  type        = list(string)
}

# Default deny all ingress in app namespace
resource "kubernetes_network_policy" "default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = "secure-app"
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

# Default deny all egress in app namespace
resource "kubernetes_network_policy" "default_deny_egress" {
  metadata {
    name      = "default-deny-egress"
    namespace = "secure-app"
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]
  }
}

# Allow API Gateway to receive external traffic
resource "kubernetes_network_policy" "allow_gateway_ingress" {
  metadata {
    name      = "allow-gateway-ingress"
    namespace = "secure-app"
  }

  spec {
    pod_selector {
      match_labels = {
        app  = "api-gateway"
        tier = "gateway"
      }
    }

    ingress {
      ports {
        port     = 8080
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

# Allow API Gateway to reach backend services
resource "kubernetes_network_policy" "allow_gateway_to_services" {
  metadata {
    name      = "allow-gateway-to-services"
    namespace = "secure-app"
  }

  spec {
    pod_selector {
      match_labels = {
        app  = "api-gateway"
        tier = "gateway"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {
            tier = "backend"
          }
        }
      }

      ports {
        port     = 8081
        protocol = "TCP"
      }

      ports {
        port     = 8082
        protocol = "TCP"
      }
    }

    # Allow DNS resolution
    egress {
      ports {
        port     = 53
        protocol = "UDP"
      }

      ports {
        port     = 53
        protocol = "TCP"
      }
    }

    policy_types = ["Egress"]
  }
}

# Allow backend services to receive from gateway only
resource "kubernetes_network_policy" "allow_backend_from_gateway" {
  metadata {
    name      = "allow-backend-from-gateway"
    namespace = "secure-app"
  }

  spec {
    pod_selector {
      match_labels = {
        tier = "backend"
      }
    }

    ingress {
      from {
        pod_selector {
          match_labels = {
            app  = "api-gateway"
            tier = "gateway"
          }
        }
      }

      ports {
        port     = 8081
        protocol = "TCP"
      }

      ports {
        port     = 8082
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

# Allow backend services to reach PostgreSQL
resource "kubernetes_network_policy" "allow_backend_to_db" {
  metadata {
    name      = "allow-backend-to-db"
    namespace = "secure-app"
  }

  spec {
    pod_selector {
      match_labels = {
        tier = "backend"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {
            app  = "postgresql"
            tier = "database"
          }
        }
      }

      ports {
        port     = 5432
        protocol = "TCP"
      }
    }

    # Allow DNS resolution
    egress {
      ports {
        port     = 53
        protocol = "UDP"
      }

      ports {
        port     = 53
        protocol = "TCP"
      }
    }

    policy_types = ["Egress"]
  }
}

# Allow Prometheus to scrape all pods
resource "kubernetes_network_policy" "allow_prometheus_scrape" {
  metadata {
    name      = "allow-prometheus-scrape"
    namespace = "secure-app"
  }

  spec {
    pod_selector {}

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "monitoring"
          }
        }

        pod_selector {
          match_labels = {
            app = "prometheus"
          }
        }
      }

      ports {
        port     = 8080
        protocol = "TCP"
      }

      ports {
        port     = 8081
        protocol = "TCP"
      }

      ports {
        port     = 8082
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}
