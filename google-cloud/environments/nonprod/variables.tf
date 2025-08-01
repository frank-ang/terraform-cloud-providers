variable "terraform_state_bucket" {
  type        = string
  description = "GCS bucket for Terraform state"
}

variable "host_project_id" {
  type        = string
  description = "Host project ID for shared VPC"
}

variable "service_project_ids" {
  type        = list(string)
  description = "Service project IDs to attach to shared VPC"
  default     = []
}

variable "region" {
  type        = string
  description = "Default region for resources"
}

variable "network_name" {
  type        = string
  description = "Name of the shared VPC network"
  default     = "nonprod-shared-vpc"
}

variable "subnets" {
  type = map(object({
    name            = string
    ip_cidr_range   = string
    region          = string
    secondary_ranges = list(object({
      range_name    = string
      ip_cidr_range = string
    }))
  }))
  description = "Subnets configuration for shared VPC"
  default = {
    primary = {
      name            = "nonprod-primary-subnet"
      ip_cidr_range   = "10.0.0.0/16"
      region          = "europe-west2"
      secondary_ranges = [
        {
          range_name    = "pods"
          ip_cidr_range = "192.168.0.0/18"
        },
        {
          range_name    = "services"
          ip_cidr_range = "192.168.64.0/20"
        }
      ]
    }
  }
}

variable "clusters" {
  type = map(object({
    project_id                    = string
    cluster_name                  = string
    location                      = string
    subnet_key                    = string
    kubernetes_version            = string
    release_channel               = string
    deletion_protection           = bool
    enable_private_endpoint       = bool
    master_ipv4_cidr_block       = string
    authorized_networks = list(object({
      cidr_block   = string
      display_name = string
    }))
    cluster_secondary_range_name  = string
    services_secondary_range_name = string
    service_account_name          = string
    service_account_roles         = list(string)
    node_pools = map(object({
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
  }))
  description = "GKE clusters configuration"
  default = {
    primary = {
      project_id              = ""
      cluster_name            = "nonprod-primary-cluster"
      location               = "europe-west2"
      subnet_key             = "primary"
      kubernetes_version     = "1.28"
      release_channel        = "REGULAR"
      deletion_protection    = false
      enable_private_endpoint = false
      master_ipv4_cidr_block = "172.16.0.0/28"
      authorized_networks    = []
      cluster_secondary_range_name  = "pods"
      services_secondary_range_name = "services"
      service_account_name   = "nonprod-gke-sa"
      service_account_roles  = []
      node_pools = {
        default = {
          initial_node_count = 0
          autoscaling = {
            min_node_count = 1
            max_node_count = 5
          }
          upgrade_settings = {
            node_pool_soak_duration = "600s"
            batch_node_count        = 2
            batch_soak_duration     = "300s"
          }
          node_config = {
            image_type                     = "COS_CONTAINERD"
            machine_type                   = "e2-standard-2"
            spot                          = false
            gcfs_enabled                  = true
            gvnic_enabled                 = true
            secure_boot_enabled           = true
            integrity_monitoring_enabled   = true
            labels                        = { environment = "nonprod" }
            tags                          = ["nonprod", "gke-node"]
            taints                        = []
          }
        }
        spot = {
          initial_node_count = 0
          autoscaling = {
            min_node_count = 0
            max_node_count = 10
          }
          upgrade_settings = {
            node_pool_soak_duration = "600s"
            batch_node_count        = 2
            batch_soak_duration     = "300s"
          }
          node_config = {
            image_type                     = "COS_CONTAINERD"
            machine_type                   = "e2-standard-2"
            spot                          = true
            gcfs_enabled                  = true
            gvnic_enabled                 = true
            secure_boot_enabled           = true
            integrity_monitoring_enabled   = true
            labels                        = { environment = "nonprod", instance_type = "spot" }
            tags                          = ["nonprod", "gke-node", "spot"]
            taints = [
              {
                key    = "instance_type"
                value  = "spot"
                effect = "NO_SCHEDULE"
              }
            ]
          }
        }
      }
    }
  }
}

variable "namespaces" {
  type = map(object({
    labels                = map(string)
    annotations           = map(string)
    enable_network_policy = bool
    allowed_namespaces    = list(string)
    resource_quota        = map(string)
    limit_range = list(object({
      type            = string
      default         = map(string)
      default_request = map(string)
      max             = map(string)
      min             = map(string)
    }))
    create_service_account = bool
    rbac_rules = list(object({
      api_groups = list(string)
      resources  = list(string)
      verbs      = list(string)
    }))
  }))
  description = "Kubernetes namespaces configuration"
  default = {
    development = {
      labels                = { team = "platform", environment = "dev" }
      annotations           = {}
      enable_network_policy = true
      allowed_namespaces    = ["kube-system", "monitoring"]
      resource_quota = {
        "requests.cpu"      = "4"
        "requests.memory"   = "8Gi"
        "limits.cpu"        = "8"
        "limits.memory"     = "16Gi"
        "pods"              = "10"
        "services"          = "5"
        "persistentvolumeclaims" = "4"
      }
      limit_range = [
        {
          type = "Container"
          default = {
            cpu    = "100m"
            memory = "128Mi"
          }
          default_request = {
            cpu    = "50m"
            memory = "64Mi"
          }
          max = {
            cpu    = "1"
            memory = "1Gi"
          }
          min = {
            cpu    = "10m"
            memory = "32Mi"
          }
        }
      ]
      create_service_account = true
      rbac_rules = [
        {
          api_groups = [""]
          resources  = ["pods", "services", "configmaps", "secrets"]
          verbs      = ["get", "list", "create", "update", "patch", "delete"]
        }
      ]
    }
    staging = {
      labels                = { team = "platform", environment = "staging" }
      annotations           = {}
      enable_network_policy = true
      allowed_namespaces    = ["kube-system", "monitoring"]
      resource_quota = {
        "requests.cpu"      = "8"
        "requests.memory"   = "16Gi"
        "limits.cpu"        = "16"
        "limits.memory"     = "32Gi"
        "pods"              = "20"
        "services"          = "10"
        "persistentvolumeclaims" = "8"
      }
      limit_range = [
        {
          type = "Container"
          default = {
            cpu    = "200m"
            memory = "256Mi"
          }
          default_request = {
            cpu    = "100m"
            memory = "128Mi"
          }
          max = {
            cpu    = "2"
            memory = "2Gi"
          }
          min = {
            cpu    = "10m"
            memory = "32Mi"
          }
        }
      ]
      create_service_account = true
      rbac_rules = [
        {
          api_groups = [""]
          resources  = ["pods", "services", "configmaps", "secrets"]
          verbs      = ["get", "list", "create", "update", "patch", "delete"]
        }
      ]
    }
  }
}

variable "enable_kafka" {
  type        = bool
  description = "Enable Kafka deployment"
  default     = false
}

variable "kafka_config" {
  type = object({
    namespace           = string
    strimzi_version    = string
    cluster_name       = string
    kafka_version      = string
    replicas           = number
    storage_size       = string
    storage_class      = string
    enable_connect     = bool
    topics = map(object({
      partitions = number
      replicas   = number
      config     = map(any)
    }))
    users = map(object({
      authentication_type = string
      acls = list(object({
        resource = object({
          type        = string
          name        = string
          patternType = string
        })
        operation = string
        host      = string
      }))
    }))
  })
  description = "Kafka configuration"
  default = {
    namespace        = "kafka"
    strimzi_version = "0.38.0"
    cluster_name    = "nonprod-kafka"
    kafka_version   = "3.6.0"
    replicas        = 1
    storage_size    = "50Gi"
    storage_class   = "standard-rwo"
    enable_connect  = false
    topics = {
      test-topic = {
        partitions = 3
        replicas   = 1
        config = {
          "retention.ms" = "604800000"
        }
      }
    }
    users = {}
  }
}

variable "enable_vault" {
  type        = bool
  description = "Enable Vault deployment"
  default     = false
}

variable "vault_config" {
  type = object({
    namespace               = string
    cluster_name           = string
    kms_location           = string
    bank_vaults_version    = string
    replicas               = number
    ha_enabled             = bool
    enable_workload_identity = bool
    monitoring_enabled     = bool
  })
  description = "Vault configuration"
  default = {
    namespace               = "vault"
    cluster_name           = "nonprod-vault"
    kms_location           = "europe-west2"
    bank_vaults_version    = "1.20.0"
    replicas               = 1
    ha_enabled             = false
    enable_workload_identity = true
    monitoring_enabled     = true
  }
}

variable "enable_cloudsql" {
  type        = bool
  description = "Enable CloudSQL PostgreSQL deployment"
  default     = false
}

variable "cloudsql_config" {
  type = object({
    instance_name       = string
    database_version   = string
    tier              = string
    availability_type = string
    disk_size         = number
    k8s_namespace     = string
    databases         = list(string)
    users = map(object({
      password        = string
      password_policy = object({
        allowed_failed_attempts      = number
        password_expiration_duration = string
        enable_failed_attempts_check = bool
        enable_password_verification = bool
      })
    }))
    deploy_proxy        = bool
    deletion_protection = bool
  })
  description = "CloudSQL configuration"
  default = {
    instance_name       = "nonprod-cloudsql"
    database_version   = "POSTGRES_15"
    tier              = "db-custom-1-3840"
    availability_type = "ZONAL"
    disk_size         = 50
    k8s_namespace     = "default"
    databases         = ["app", "test"]
    users = {
      app = {
        password        = null
        password_policy = null
      }
    }
    deploy_proxy        = true
    deletion_protection = false
  }
}

variable "enable_alloydb" {
  type        = bool
  description = "Enable AlloyDB deployment"
  default     = false
}

variable "alloydb_config" {
  type = object({
    cluster_id       = string
    database_version = string
    display_name     = string
    k8s_namespace    = string
    primary_instance = object({
      cpu_count               = number
      availability_type       = string
      database_flags         = map(string)
      read_pool_node_count   = number
    })
    users = map(object({
      user_type       = string
      password        = string
      database_roles  = list(string)
    }))
    deploy_proxy = bool
  })
  description = "AlloyDB configuration"
  default = {
    cluster_id       = "nonprod-alloydb"
    database_version = "POSTGRES_15"
    display_name     = "Non-Prod AlloyDB Cluster"
    k8s_namespace    = "default"
    primary_instance = {
      cpu_count               = 2
      availability_type       = "ZONAL"
      database_flags         = {}
      read_pool_node_count   = 0
    }
    users = {
      app = {
        user_type      = "ALLOYDB_BUILT_IN"
        password       = null
        database_roles = []
      }
    }
    deploy_proxy = true
  }
}