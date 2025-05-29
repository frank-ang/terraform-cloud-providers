terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Create KMS key for Vault auto-unseal
resource "google_kms_key_ring" "vault" {
  name     = "${var.vault_cluster_name}-keyring"
  location = var.kms_location
  project  = var.project_id
}

resource "google_kms_crypto_key" "vault_unseal" {
  name     = "${var.vault_cluster_name}-unseal-key"
  key_ring = google_kms_key_ring.vault.id
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

# Service account for Vault KMS access
resource "google_service_account" "vault_kms" {
  account_id   = "${var.vault_cluster_name}-kms"
  display_name = "Vault KMS Service Account"
  description  = "Service account for Vault KMS auto-unseal"
  project      = var.project_id
}

resource "google_kms_crypto_key_iam_member" "vault_kms" {
  crypto_key_id = google_kms_crypto_key.vault_unseal.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.vault_kms.email}"
}

resource "google_service_account_key" "vault_kms" {
  service_account_id = google_service_account.vault_kms.name
}

# Create namespace for Vault
resource "kubernetes_namespace" "vault" {
  count = var.create_namespace ? 1 : 0
  
  metadata {
    name = var.vault_namespace
    labels = {
      name         = var.vault_namespace
      managed-by   = "terraform"
      component    = "vault"
      environment  = var.environment
    }
  }
}

# Secret for KMS credentials
resource "kubernetes_secret" "vault_kms_creds" {
  metadata {
    name      = "vault-kms-creds"
    namespace = var.vault_namespace
  }

  data = {
    "credentials.json" = base64decode(google_service_account_key.vault_kms.private_key)
  }

  depends_on = [kubernetes_namespace.vault]
}

# Install Bank Vaults Operator
resource "helm_release" "bank_vaults_operator" {
  name       = "bank-vaults"
  repository = "https://kubernetes-charts.banzaicloud.com"
  chart      = "bank-vaults"
  version    = var.bank_vaults_version
  namespace  = var.vault_namespace

  values = [yamlencode({
    operator = {
      image = {
        repository = var.bank_vaults_image_repository
        tag        = var.bank_vaults_image_tag
      }
      
      resources = var.operator_resources
      
      tolerations  = var.operator_tolerations
      affinity     = var.operator_affinity
      nodeSelector = var.operator_node_selector
    }
    
    webhook = {
      enabled = var.webhook_enabled
      
      image = {
        repository = var.webhook_image_repository
        tag        = var.webhook_image_tag
      }
      
      resources = var.webhook_resources
      
      tolerations  = var.webhook_tolerations
      affinity     = var.webhook_affinity
      nodeSelector = var.webhook_node_selector
    }
  })]

  depends_on = [kubernetes_namespace.vault]
}

# Vault Custom Resource
resource "kubernetes_manifest" "vault_instance" {
  count = var.create_vault_instance ? 1 : 0
  
  manifest = {
    apiVersion = "vault.banzaicloud.com/v1alpha1"
    kind       = "Vault"
    
    metadata = {
      name      = var.vault_cluster_name
      namespace = var.vault_namespace
      labels = {
        environment = var.environment
        managed-by  = "terraform"
      }
    }
    
    spec = {
      size = var.vault_replicas
      image = "${var.vault_image_repository}:${var.vault_image_tag}"
      
      bankVaultsImage = "${var.bank_vaults_image_repository}:${var.bank_vaults_image_tag}"
      
      # Storage configuration
      storage = {
        type = "file"
        config = {
          path = "/vault/data"
        }
      }
      
      # Auto-unseal with GCP KMS
      unsealConfig = {
        google = {
          kmsKeyId = google_kms_crypto_key.vault_unseal.id
          kmsProject = var.project_id
          credentialsPath = "/vault/kms/credentials.json"
        }
      }
      
      # HA configuration
      ha = {
        enabled = var.vault_ha_enabled
        replicas = var.vault_replicas
      }
      
      # TLS configuration
      tls = {
        secretName = var.tls_secret_name
      }
      
      # Resources
      resources = var.vault_resources
      
      # Security context
      securityContext = {
        runAsUser    = 1000
        runAsGroup   = 1000
        fsGroup      = 1000
        runAsNonRoot = true
      }
      
      # Pod template
      podSpec = {
        tolerations  = var.vault_tolerations
        affinity     = var.vault_affinity
        nodeSelector = var.vault_node_selector
        
        volumes = [
          {
            name = "kms-credentials"
            secret = {
              secretName = kubernetes_secret.vault_kms_creds.metadata[0].name
            }
          }
        ]
        
        volumeMounts = [
          {
            name      = "kms-credentials"
            mountPath = "/vault/kms"
            readOnly  = true
          }
        ]
      }
      
      # Vault configuration
      config = merge(
        {
          storage = {
            file = {
              path = "/vault/data"
            }
          }
          
          listener = {
            tcp = {
              address     = "0.0.0.0:8200"
              tls_disable = false
              tls_cert_file = "/vault/tls/server.crt"
              tls_key_file  = "/vault/tls/server.key"
            }
          }
          
          seal = {
            gcpckms = {
              project     = var.project_id
              region      = var.kms_location
              key_ring    = google_kms_key_ring.vault.name
              crypto_key  = google_kms_crypto_key.vault_unseal.name
              credentials = "/vault/kms/credentials.json"
            }
          }
          
          ui = true
          
          log_level = var.vault_log_level
          
          api_addr = "https://${var.vault_cluster_name}.${var.vault_namespace}.svc.cluster.local:8200"
          cluster_addr = "https://${var.vault_cluster_name}.${var.vault_namespace}.svc.cluster.local:8201"
        },
        var.vault_config
      )
      
      # External configuration (policies, auth methods, etc.)
      externalConfig = var.vault_external_config
      
      # Service account
      serviceAccount = var.vault_service_account_name
      
      # Service configuration
      service = {
        type = "ClusterIP"
        port = 8200
        annotations = var.service_annotations
      }
      
      # Ingress configuration
      ingress = var.ingress_enabled ? {
        enabled = true
        annotations = var.ingress_annotations
        hosts = var.ingress_hosts
        tls = var.ingress_tls
      } : null
      
      # Monitoring
      serviceMonitor = {
        enabled = var.monitoring_enabled
      }
    }
  }
  
  depends_on = [helm_release.bank_vaults_operator]
}

# TLS Certificate Secret (if not provided externally)
resource "kubernetes_secret" "vault_tls" {
  count = var.create_tls_secret ? 1 : 0
  
  metadata {
    name      = var.tls_secret_name
    namespace = var.vault_namespace
  }
  
  type = "kubernetes.io/tls"
  
  data = {
    "tls.crt" = var.tls_cert_data
    "tls.key" = var.tls_key_data
  }
  
  depends_on = [kubernetes_namespace.vault]
}

# Service Account for Vault
resource "kubernetes_service_account" "vault" {
  count = var.create_service_account ? 1 : 0
  
  metadata {
    name      = var.vault_service_account_name
    namespace = var.vault_namespace
    annotations = merge(
      var.service_account_annotations,
      {
        "iam.gke.io/gcp-service-account" = google_service_account.vault_kms.email
      }
    )
  }
  
  depends_on = [kubernetes_namespace.vault]
}

# Workload Identity binding
resource "google_service_account_iam_member" "vault_workload_identity" {
  count = var.enable_workload_identity ? 1 : 0
  
  service_account_id = google_service_account.vault_kms.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.vault_namespace}/${var.vault_service_account_name}]"
}

# RBAC for Vault
resource "kubernetes_cluster_role" "vault" {
  count = var.create_rbac ? 1 : 0
  
  metadata {
    name = "${var.vault_cluster_name}-vault"
  }
  
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "create", "update", "delete"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts"]
    verbs      = ["get", "list", "create", "update", "patch"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts/token"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding" "vault" {
  count = var.create_rbac ? 1 : 0
  
  metadata {
    name = "${var.vault_cluster_name}-vault"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.vault[0].metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = var.vault_service_account_name
    namespace = var.vault_namespace
  }
}