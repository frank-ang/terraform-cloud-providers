terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace_name
    labels = merge(
      var.labels,
      {
        "name"                = var.namespace_name
        "managed-by"          = "terraform"
        "environment"         = var.environment
      }
    )
    annotations = var.annotations
  }
}

# Network Policy for namespace isolation
resource "kubernetes_network_policy" "namespace_isolation" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-isolation"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    # Allow ingress from same namespace
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = var.namespace_name
          }
        }
      }
    }

    # Allow ingress from system namespaces
    dynamic "ingress" {
      for_each = var.allowed_namespaces
      content {
        from {
          namespace_selector {
            match_labels = {
              name = ingress.value
            }
          }
        }
      }
    }

    # Allow egress to same namespace
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = var.namespace_name
          }
        }
      }
    }

    # Allow egress to system namespaces and external
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-public"
          }
        }
      }
    }

    # Allow DNS resolution
    egress {
      to {}
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    # Allow HTTPS traffic
    egress {
      to {}
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
  }
}

# Resource Quota
resource "kubernetes_resource_quota" "namespace_quota" {
  count = var.resource_quota != null ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-quota"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  spec {
    hard = var.resource_quota
  }
}

# Limit Range
resource "kubernetes_limit_range" "namespace_limits" {
  count = var.limit_range != null ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-limits"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  spec {
    dynamic "limit" {
      for_each = var.limit_range
      content {
        type = limit.value.type
        default = limit.value.default
        default_request = limit.value.default_request
        max = limit.value.max
        min = limit.value.min
      }
    }
  }
}

# Pod Security Policy (if enabled)
resource "kubernetes_pod_security_policy" "namespace_psp" {
  count = var.pod_security_policy != null ? 1 : 0

  metadata {
    name = "${var.namespace_name}-psp"
  }

  spec {
    privileged                 = var.pod_security_policy.privileged
    allow_privilege_escalation = var.pod_security_policy.allow_privilege_escalation
    
    allowed_capabilities       = var.pod_security_policy.allowed_capabilities
    required_drop_capabilities = var.pod_security_policy.required_drop_capabilities
    
    volumes = var.pod_security_policy.volumes
    
    run_as_user {
      rule = var.pod_security_policy.run_as_user_rule
      ranges {
        min = var.pod_security_policy.run_as_user_min
        max = var.pod_security_policy.run_as_user_max
      }
    }
    
    se_linux {
      rule = var.pod_security_policy.se_linux_rule
    }
    
    fs_group {
      rule = var.pod_security_policy.fs_group_rule
      ranges {
        min = var.pod_security_policy.fs_group_min
        max = var.pod_security_policy.fs_group_max
      }
    }
  }
}

# Service Account for namespace
resource "kubernetes_service_account" "namespace_sa" {
  count = var.create_service_account ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-sa"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    annotations = var.service_account_annotations
  }

  automount_service_account_token = var.automount_service_account_token
}

# RBAC for service account
resource "kubernetes_role" "namespace_role" {
  count = var.create_service_account && length(var.rbac_rules) > 0 ? 1 : 0

  metadata {
    namespace = kubernetes_namespace.namespace.metadata[0].name
    name      = "${var.namespace_name}-role"
  }

  dynamic "rule" {
    for_each = var.rbac_rules
    content {
      api_groups = rule.value.api_groups
      resources  = rule.value.resources
      verbs      = rule.value.verbs
    }
  }
}

resource "kubernetes_role_binding" "namespace_role_binding" {
  count = var.create_service_account && length(var.rbac_rules) > 0 ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-role-binding"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.namespace_role[0].metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.namespace_sa[0].metadata[0].name
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
}