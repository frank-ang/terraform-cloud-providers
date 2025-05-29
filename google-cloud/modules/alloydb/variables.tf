variable "project_id" {
  type        = string
  description = "The project ID to host the AlloyDB cluster"
}

variable "cluster_id" {
  type        = string
  description = "The ID of the AlloyDB cluster"
}

variable "region" {
  type        = string
  description = "The region where the AlloyDB cluster will be created"
}

variable "network_self_link" {
  type        = string
  description = "The VPC network self-link for AlloyDB"
}

variable "database_version" {
  type        = string
  description = "The database version for AlloyDB"
  default     = "POSTGRES_15"
  validation {
    condition = contains([
      "POSTGRES_13", "POSTGRES_14", "POSTGRES_15"
    ], var.database_version)
    error_message = "Database version must be a supported PostgreSQL version for AlloyDB."
  }
}

variable "display_name" {
  type        = string
  description = "The display name for the AlloyDB cluster"
  default     = null
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to AlloyDB resources"
  default     = {}
}

variable "deletion_policy" {
  type        = string
  description = "Deletion policy for the AlloyDB cluster"
  default     = "DEFAULT"
  validation {
    condition     = contains(["DEFAULT", "FORCE"], var.deletion_policy)
    error_message = "Deletion policy must be either DEFAULT or FORCE."
  }
}

variable "encryption_key" {
  type        = string
  description = "KMS key for cluster encryption"
  default     = null
}

# Initial User Configuration
variable "initial_user" {
  type = object({
    username = string
    password = string
  })
  description = "Initial user configuration for AlloyDB cluster"
  default = {
    username = "postgres"
    password = null
  }
}

# Backup Configuration
variable "backup_enabled" {
  type        = bool
  description = "Enable automated backups"
  default     = true
}

variable "backup_window" {
  type        = string
  description = "Backup window duration (e.g., '3600s')"
  default     = "3600s"
}

variable "backup_location" {
  type        = string
  description = "Location for storing backups"
  default     = null
}

variable "backup_labels" {
  type        = map(string)
  description = "Labels for backup resources"
  default     = {}
}

variable "backup_days_of_week" {
  type        = list(string)
  description = "Days of week for backups"
  default     = ["SUNDAY"]
  validation {
    condition = alltrue([
      for day in var.backup_days_of_week :
      contains(["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"], day)
    ])
    error_message = "Backup days must be valid days of the week."
  }
}

variable "backup_start_hour" {
  type        = number
  description = "Hour to start backups (0-23)"
  default     = 3
  validation {
    condition     = var.backup_start_hour >= 0 && var.backup_start_hour <= 23
    error_message = "Backup start hour must be between 0 and 23."
  }
}

variable "backup_start_minute" {
  type        = number
  description = "Minute to start backups (0-59)"
  default     = 0
  validation {
    condition     = var.backup_start_minute >= 0 && var.backup_start_minute <= 59
    error_message = "Backup start minute must be between 0 and 59."
  }
}

variable "backup_retention_count" {
  type        = number
  description = "Number of backups to retain"
  default     = 30
}

variable "backup_encryption_key" {
  type        = string
  description = "KMS key for backup encryption"
  default     = null
}

# Continuous Backup Configuration
variable "continuous_backup_enabled" {
  type        = bool
  description = "Enable continuous backup"
  default     = true
}

variable "continuous_backup_recovery_window_days" {
  type        = number
  description = "Recovery window for continuous backup in days"
  default     = 14
}

variable "continuous_backup_encryption_key" {
  type        = string
  description = "KMS key for continuous backup encryption"
  default     = null
}

# Primary Instance Configuration
variable "primary_instance" {
  type = object({
    cpu_count               = number
    availability_type       = string
    database_flags         = map(string)
    read_pool_node_count   = number
  })
  description = "Configuration for the primary AlloyDB instance"
  default = {
    cpu_count               = 2
    availability_type       = "ZONAL"
    database_flags         = {}
    read_pool_node_count   = 0
  }
  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.primary_instance.availability_type)
    error_message = "Primary instance availability type must be either ZONAL or REGIONAL."
  }
}

# Read Replica Configuration
variable "read_replica_count" {
  type        = number
  description = "Number of read replicas to create"
  default     = 0
}

variable "read_replica_config" {
  type = object({
    cpu_count               = number
    availability_type       = string
    database_flags         = map(string)
    read_pool_node_count   = number
  })
  description = "Configuration for read replica instances"
  default = {
    cpu_count               = 2
    availability_type       = "ZONAL"
    database_flags         = {}
    read_pool_node_count   = 1
  }
  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.read_replica_config.availability_type)
    error_message = "Read replica availability type must be either ZONAL or REGIONAL."
  }
}

# Users Configuration
variable "users" {
  type = map(object({
    user_type       = string
    password        = string
    database_roles  = list(string)
  }))
  description = "Map of AlloyDB users to create"
  default = {
    app = {
      user_type      = "ALLOYDB_BUILT_IN"
      password       = null
      database_roles = []
    }
  }
  validation {
    condition = alltrue([
      for user in var.users :
      contains(["ALLOYDB_BUILT_IN", "ALLOYDB_IAM_USER"], user.user_type)
    ])
    error_message = "User type must be either ALLOYDB_BUILT_IN or ALLOYDB_IAM_USER."
  }
}

# Kubernetes Configuration
variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace for AlloyDB resources"
  default     = "default"
}

variable "create_k8s_secret" {
  type        = bool
  description = "Create Kubernetes secret with database credentials"
  default     = true
}

variable "create_k8s_service_account" {
  type        = bool
  description = "Create Kubernetes service account for AlloyDB proxy"
  default     = true
}

variable "k8s_service_account_name" {
  type        = string
  description = "Name of the Kubernetes service account"
  default     = "alloydb-proxy"
}

variable "k8s_service_account_annotations" {
  type        = map(string)
  description = "Annotations for the Kubernetes service account"
  default     = {}
}

variable "enable_workload_identity" {
  type        = bool
  description = "Enable Workload Identity for the service account"
  default     = true
}

variable "create_k8s_resources" {
  type        = bool
  description = "Create Kubernetes resources (ConfigMap, etc.)"
  default     = true
}

# AlloyDB Auth Proxy Configuration
variable "deploy_proxy" {
  type        = bool
  description = "Deploy AlloyDB Auth Proxy as a Kubernetes deployment"
  default     = false
}

variable "proxy_replicas" {
  type        = number
  description = "Number of AlloyDB proxy replicas"
  default     = 2
}

variable "proxy_image_tag" {
  type        = string
  description = "Docker image tag for AlloyDB Auth Proxy"
  default     = "1.5.0"
}

variable "proxy_resources" {
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
  description = "Resource limits and requests for AlloyDB proxy"
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

variable "proxy_tolerations" {
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  description = "Tolerations for AlloyDB proxy pods"
  default     = []
}

variable "proxy_affinity" {
  type        = any
  description = "Affinity rules for AlloyDB proxy pods"
  default     = null
}

variable "proxy_node_selector" {
  type        = map(string)
  description = "Node selector for AlloyDB proxy pods"
  default     = {}
}