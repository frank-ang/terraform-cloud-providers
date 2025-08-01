variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "vault_namespace" {
  type        = string
  description = "Kubernetes namespace for Vault"
  default     = "vault"
}

variable "create_namespace" {
  type        = bool
  description = "Create the Vault namespace"
  default     = true
}

variable "environment" {
  type        = string
  description = "Environment label"
  default     = "development"
}

variable "vault_cluster_name" {
  type        = string
  description = "Name of the Vault cluster"
  default     = "vault"
}

variable "kms_location" {
  type        = string
  description = "Location for KMS key ring"
  default     = "global"
}

variable "bank_vaults_version" {
  type        = string
  description = "Version of Bank Vaults operator"
  default     = "1.20.0"
}

variable "bank_vaults_image_repository" {
  type        = string
  description = "Bank Vaults image repository"
  default     = "ghcr.io/bank-vaults/bank-vaults"
}

variable "bank_vaults_image_tag" {
  type        = string
  description = "Bank Vaults image tag"
  default     = "1.20.0"
}

variable "webhook_enabled" {
  type        = bool
  description = "Enable Bank Vaults webhook"
  default     = true
}

variable "webhook_image_repository" {
  type        = string
  description = "Bank Vaults webhook image repository"
  default     = "ghcr.io/bank-vaults/vault-secrets-webhook"
}

variable "webhook_image_tag" {
  type        = string
  description = "Bank Vaults webhook image tag"
  default     = "1.20.0"
}

variable "operator_resources" {
  type = object({
    limits = object({
      memory = string
      cpu    = string
    })
    requests = object({
      memory = string
      cpu    = string
    })
  })
  description = "Resource limits and requests for Bank Vaults operator"
  default = {
    limits = {
      memory = "256Mi"
      cpu    = "200m"
    }
    requests = {
      memory = "128Mi"
      cpu    = "100m"
    }
  }
}

variable "operator_tolerations" {
  type        = list(any)
  description = "Tolerations for operator pods"
  default     = []
}

variable "operator_affinity" {
  type        = any
  description = "Affinity rules for operator pods"
  default     = {}
}

variable "operator_node_selector" {
  type        = map(string)
  description = "Node selector for operator pods"
  default     = {}
}

variable "webhook_resources" {
  type = object({
    limits = object({
      memory = string
      cpu    = string
    })
    requests = object({
      memory = string
      cpu    = string
    })
  })
  description = "Resource limits and requests for webhook"
  default = {
    limits = {
      memory = "256Mi"
      cpu    = "200m"
    }
    requests = {
      memory = "128Mi"
      cpu    = "100m"
    }
  }
}

variable "webhook_tolerations" {
  type        = list(any)
  description = "Tolerations for webhook pods"
  default     = []
}

variable "webhook_affinity" {
  type        = any
  description = "Affinity rules for webhook pods"
  default     = {}
}

variable "webhook_node_selector" {
  type        = map(string)
  description = "Node selector for webhook pods"
  default     = {}
}

variable "create_vault_instance" {
  type        = bool
  description = "Create Vault instance"
  default     = true
}

variable "vault_replicas" {
  type        = number
  description = "Number of Vault replicas"
  default     = 3
}

variable "vault_image_repository" {
  type        = string
  description = "Vault image repository"
  default     = "hashicorp/vault"
}

variable "vault_image_tag" {
  type        = string
  description = "Vault image tag"
  default     = "1.15.2"
}

variable "vault_ha_enabled" {
  type        = bool
  description = "Enable Vault HA mode"
  default     = true
}

variable "vault_resources" {
  type = object({
    limits = object({
      memory = string
      cpu    = string
    })
    requests = object({
      memory = string
      cpu    = string
    })
  })
  description = "Resource limits and requests for Vault"
  default = {
    limits = {
      memory = "2Gi"
      cpu    = "1000m"
    }
    requests = {
      memory = "1Gi"
      cpu    = "500m"
    }
  }
}

variable "vault_tolerations" {
  type        = list(any)
  description = "Tolerations for Vault pods"
  default     = []
}

variable "vault_affinity" {
  type        = any
  description = "Affinity rules for Vault pods"
  default     = {}
}

variable "vault_node_selector" {
  type        = map(string)
  description = "Node selector for Vault pods"
  default     = {}
}

variable "vault_log_level" {
  type        = string
  description = "Vault log level"
  default     = "INFO"
  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR"], var.vault_log_level)
    error_message = "Vault log level must be one of: TRACE, DEBUG, INFO, WARN, ERROR."
  }
}

variable "vault_config" {
  type        = any
  description = "Additional Vault configuration"
  default     = {}
}

variable "vault_external_config" {
  type        = any
  description = "External Vault configuration (policies, auth methods, etc.)"
  default     = {}
}

variable "vault_service_account_name" {
  type        = string
  description = "Name of the Vault service account"
  default     = "vault"
}

variable "create_service_account" {
  type        = bool
  description = "Create service account for Vault"
  default     = true
}

variable "service_account_annotations" {
  type        = map(string)
  description = "Annotations for the Vault service account"
  default     = {}
}

variable "enable_workload_identity" {
  type        = bool
  description = "Enable Workload Identity for Vault"
  default     = true
}

variable "create_rbac" {
  type        = bool
  description = "Create RBAC resources for Vault"
  default     = true
}

variable "tls_secret_name" {
  type        = string
  description = "Name of the TLS secret for Vault"
  default     = "vault-tls"
}

variable "create_tls_secret" {
  type        = bool
  description = "Create TLS secret for Vault"
  default     = false
}

variable "tls_cert_data" {
  type        = string
  description = "TLS certificate data (base64 encoded)"
  default     = ""
  sensitive   = true
}

variable "tls_key_data" {
  type        = string
  description = "TLS private key data (base64 encoded)"
  default     = ""
  sensitive   = true
}

variable "service_annotations" {
  type        = map(string)
  description = "Annotations for the Vault service"
  default     = {}
}

variable "ingress_enabled" {
  type        = bool
  description = "Enable ingress for Vault"
  default     = false
}

variable "ingress_annotations" {
  type        = map(string)
  description = "Annotations for the Vault ingress"
  default     = {}
}

variable "ingress_hosts" {
  type        = list(string)
  description = "Hosts for the Vault ingress"
  default     = []
}

variable "ingress_tls" {
  type        = list(any)
  description = "TLS configuration for the Vault ingress"
  default     = []
}

variable "monitoring_enabled" {
  type        = bool
  description = "Enable monitoring for Vault"
  default     = true
}