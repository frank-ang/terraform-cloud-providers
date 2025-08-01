variable "project_id" {
  type        = string
  description = "The project ID to host the CloudSQL instance"
}

variable "instance_name" {
  type        = string
  description = "The name of the CloudSQL instance"
}

variable "region" {
  type        = string
  description = "The region where the CloudSQL instance will be created"
}

variable "database_version" {
  type        = string
  description = "The database version to use"
  default     = "POSTGRES_15"
  validation {
    condition = contains([
      "POSTGRES_13", "POSTGRES_14", "POSTGRES_15", "POSTGRES_16"
    ], var.database_version)
    error_message = "Database version must be a supported PostgreSQL version."
  }
}

variable "tier" {
  type        = string
  description = "The machine type to use for the CloudSQL instance"
  default     = "db-custom-1-3840"
}

variable "availability_type" {
  type        = string
  description = "The availability type of the CloudSQL instance"
  default     = "ZONAL"
  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "Availability type must be either ZONAL or REGIONAL."
  }
}

variable "disk_type" {
  type        = string
  description = "The disk type for the CloudSQL instance"
  default     = "PD_SSD"
  validation {
    condition     = contains(["PD_SSD", "PD_HDD"], var.disk_type)
    error_message = "Disk type must be either PD_SSD or PD_HDD."
  }
}

variable "disk_size" {
  type        = number
  description = "The disk size for the CloudSQL instance in GB"
  default     = 100
}

variable "disk_autoresize" {
  type        = bool
  description = "Enable automatic disk size increase"
  default     = true
}

variable "disk_autoresize_limit" {
  type        = number
  description = "The maximum disk size for automatic resize in GB"
  default     = 1000
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection for the CloudSQL instance"
  default     = true
}

variable "private_network" {
  type        = string
  description = "The VPC network self-link for private IP"
}

variable "require_ssl" {
  type        = bool
  description = "Require SSL connections to the database"
  default     = true
}

variable "authorized_networks" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "List of authorized networks for CloudSQL access"
  default     = []
}

variable "backup_enabled" {
  type        = bool
  description = "Enable automated backups"
  default     = true
}

variable "backup_start_time" {
  type        = string
  description = "Start time for automated backups (HH:MM format)"
  default     = "03:00"
}

variable "backup_location" {
  type        = string
  description = "Location for storing backups"
  default     = null
}

variable "point_in_time_recovery_enabled" {
  type        = bool
  description = "Enable point-in-time recovery"
  default     = true
}

variable "transaction_log_retention_days" {
  type        = number
  description = "Number of days to retain transaction logs"
  default     = 7
}

variable "backup_retained_backups" {
  type        = number
  description = "Number of backups to retain"
  default     = 30
}

variable "maintenance_window_day" {
  type        = number
  description = "Day of week for maintenance (1-7, where 1 is Monday)"
  default     = 7
  validation {
    condition     = var.maintenance_window_day >= 1 && var.maintenance_window_day <= 7
    error_message = "Maintenance window day must be between 1 and 7."
  }
}

variable "maintenance_window_hour" {
  type        = number
  description = "Hour for maintenance window (0-23)"
  default     = 3
  validation {
    condition     = var.maintenance_window_hour >= 0 && var.maintenance_window_hour <= 23
    error_message = "Maintenance window hour must be between 0 and 23."
  }
}

variable "maintenance_window_update_track" {
  type        = string
  description = "Update track for maintenance"
  default     = "stable"
  validation {
    condition     = contains(["canary", "stable"], var.maintenance_window_update_track)
    error_message = "Maintenance window update track must be either canary or stable."
  }
}

variable "query_insights_enabled" {
  type        = bool
  description = "Enable query insights"
  default     = true
}

variable "query_string_length" {
  type        = number
  description = "Maximum query string length for insights"
  default     = 1024
}

variable "record_application_tags" {
  type        = bool
  description = "Record application tags in query insights"
  default     = true
}

variable "record_client_address" {
  type        = bool
  description = "Record client address in query insights"
  default     = false
}

variable "database_flags" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "Additional database flags to set"
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the CloudSQL instance"
  default     = {}
}

variable "databases" {
  type        = list(string)
  description = "List of databases to create"
  default     = ["app"]
}

variable "users" {
  type = map(object({
    password = string
    password_policy = object({
      allowed_failed_attempts      = number
      password_expiration_duration = string
      enable_failed_attempts_check = bool
      enable_password_verification = bool
    })
  }))
  description = "Map of database users to create"
  default = {
    app = {
      password        = null
      password_policy = null
    }
  }
}

# Kubernetes Configuration
variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace for CloudSQL resources"
  default     = "default"
}

variable "create_k8s_secret" {
  type        = bool
  description = "Create Kubernetes secret with database credentials"
  default     = true
}

variable "create_k8s_service_account" {
  type        = bool
  description = "Create Kubernetes service account for CloudSQL proxy"
  default     = true
}

variable "k8s_service_account_name" {
  type        = string
  description = "Name of the Kubernetes service account"
  default     = "cloudsql-proxy"
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

# Cloud SQL Proxy Configuration
variable "deploy_proxy" {
  type        = bool
  description = "Deploy CloudSQL Auth Proxy as a Kubernetes deployment"
  default     = false
}

variable "proxy_replicas" {
  type        = number
  description = "Number of CloudSQL proxy replicas"
  default     = 2
}

variable "proxy_image_tag" {
  type        = string
  description = "Docker image tag for CloudSQL proxy"
  default     = "2.8.0"
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
  description = "Resource limits and requests for CloudSQL proxy"
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
  description = "Tolerations for CloudSQL proxy pods"
  default     = []
}

variable "proxy_affinity" {
  type        = any
  description = "Affinity rules for CloudSQL proxy pods"
  default     = null
}

variable "proxy_node_selector" {
  type        = map(string)
  description = "Node selector for CloudSQL proxy pods"
  default     = {}
}