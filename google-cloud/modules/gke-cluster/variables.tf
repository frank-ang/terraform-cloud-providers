variable "project_id" {
  type        = string
  description = "The project ID to host the cluster in"
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster"
}

variable "location" {
  type        = string
  description = "The location (region or zone) of the cluster"
}

variable "network_self_link" {
  type        = string
  description = "The VPC network self link to host the cluster in"
}

variable "subnetwork_self_link" {
  type        = string
  description = "The subnetwork self link to host the cluster in"
}

variable "kubernetes_version" {
  type        = string
  description = "The Kubernetes version of the masters"
  default     = "latest"
}

variable "release_channel" {
  type        = string
  description = "The release channel of this cluster"
  default     = "STABLE"
  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Whether or not to allow Terraform to destroy the cluster"
  default     = true
}

variable "enable_private_endpoint" {
  type        = bool
  description = "Whether the master's internal IP address is used as the cluster endpoint"
  default     = false
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "The IP range in CIDR notation to use for the hosted master network"
  default     = "172.16.0.0/28"
}

variable "authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  description = "List of master authorized networks"
  default     = []
}

variable "cluster_secondary_range_name" {
  type        = string
  description = "The name of the secondary subnet ip range to use for pods"
}

variable "services_secondary_range_name" {
  type        = string
  description = "The name of the secondary subnet range to use for services"
}

variable "cluster_autoscaling_enabled" {
  type        = bool
  description = "Enable cluster autoscaling"
  default     = true
}

variable "cluster_autoscaling_resource_limits" {
  type = list(object({
    resource_type = string
    minimum       = number
    maximum       = number
  }))
  description = "Cluster autoscaling resource limits"
  default = [
    {
      resource_type = "memory"
      minimum       = 8
      maximum       = 64
    },
    {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 10
    }
  ]
}

variable "service_account_name" {
  type        = string
  description = "The name of the service account"
}

variable "service_account_roles" {
  type        = list(string)
  description = "Additional roles to be added to the service account"
  default     = []
}

variable "addons_config" {
  type = object({
    http_load_balancing_disabled           = bool
    horizontal_pod_autoscaling_disabled    = bool
    network_policy_disabled                = bool
    filestore_csi_driver_enabled           = bool
    gce_pd_csi_driver_enabled             = bool
  })
  description = "The configuration for addons supported by GKE"
  default = {
    http_load_balancing_disabled           = false
    horizontal_pod_autoscaling_disabled    = false
    network_policy_disabled                = false
    filestore_csi_driver_enabled           = true
    gce_pd_csi_driver_enabled             = true
  }
}

variable "network_policy_enabled" {
  type        = bool
  description = "Enable network policy addon"
  default     = true
}

variable "pod_security_policy_enabled" {
  type        = bool
  description = "Enable PodSecurityPolicy addon"
  default     = false
}

variable "binary_authorization_evaluation_mode" {
  type        = string
  description = "Mode of operation for Binary Authorization policy evaluation"
  default     = "DISABLED"
  validation {
    condition     = contains(["DISABLED", "PROJECT_SINGLETON_POLICY_ENFORCE"], var.binary_authorization_evaluation_mode)
    error_message = "Binary authorization evaluation mode must be DISABLED or PROJECT_SINGLETON_POLICY_ENFORCE."
  }
}

variable "usage_metering_dataset_id" {
  type        = string
  description = "The ID of a BigQuery Dataset for using BigQuery as the destination of resource usage export"
  default     = null
}

variable "logging_components" {
  type        = list(string)
  description = "List of GKE components exposing logs"
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS", "API_SERVER"]
}

variable "monitoring_components" {
  type        = list(string)
  description = "List of GKE components exposing metrics"
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS", "API_SERVER", "CONTROLLER_MANAGER", "SCHEDULER"]
}

variable "managed_prometheus_enabled" {
  type        = bool
  description = "Configuration for Managed Service for Prometheus"
  default     = true
}

variable "node_pools" {
  type = map(object({
    initial_node_count = number
    autoscaling = object({
      min_node_count = number
      max_node_count = number
    })
    upgrade_settings = object({
      node_pool_soak_duration = string
      batch_node_count        = number
      batch_soak_duration     = string
    })
    node_config = object({
      image_type                     = string
      machine_type                   = string
      spot                          = bool
      gcfs_enabled                  = bool
      gvnic_enabled                 = bool
      secure_boot_enabled           = bool
      integrity_monitoring_enabled   = bool
      labels                        = map(string)
      tags                          = list(string)
      taints = list(object({
        key    = string
        value  = string
        effect = string
      }))
    })
  }))
  description = "List of maps containing node pools"
  default = {
    default = {
      initial_node_count = 0
      autoscaling = {
        min_node_count = 1
        max_node_count = 3
      }
      upgrade_settings = {
        node_pool_soak_duration = "600s"
        batch_node_count        = 2
        batch_soak_duration     = "300s"
      }
      node_config = {
        image_type                     = "COS_CONTAINERD"
        machine_type                   = "e2-standard-4"
        spot                          = false
        gcfs_enabled                  = true
        gvnic_enabled                 = true
        secure_boot_enabled           = true
        integrity_monitoring_enabled   = true
        labels                        = {}
        tags                          = []
        taints                        = []
      }
    }
  }
}