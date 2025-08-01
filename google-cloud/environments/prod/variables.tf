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
  default     = "prod-shared-vpc"
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
      name            = "prod-primary-subnet"
      ip_cidr_range   = "10.1.0.0/16"
      region          = "europe-west2"
      secondary_ranges = [
        {
          range_name    = "pods"
          ip_cidr_range = "192.169.0.0/18"
        },
        {
          range_name    = "services"
          ip_cidr_range = "192.169.64.0/20"
        }
      ]
    }
    secondary = {
      name            = "prod-secondary-subnet"
      ip_cidr_range   = "10.2.0.0/16"
      region          = "europe-west1"
      secondary_ranges = [
        {
          range_name    = "pods"
          ip_cidr_range = "192.170.0.0/18"
        },
        {
          range_name    = "services"
          ip_cidr_range = "192.170.64.0/20"
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
    usage_metering_dataset_id     = string
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
      cluster_name            = "prod-primary-cluster"
      location               = "europe-west2"
      subnet_key             = "primary"
      kubernetes_version     = "1.28"
      release_channel        = "STABLE"
      deletion_protection    = true
      enable_private_endpoint = true
      master_ipv4_cidr_block = "172.17.0.0/28"
      authorized_networks = [
        {
          cidr_block   = "10.0.0.0/8"
          display_name = "Internal networks"
        }
      ]
      cluster_secondary_range_name  = "pods"
      services_secondary_range_name = "services"
      service_account_name   = "prod-gke-sa"
      service_account_roles  = []
      usage_metering_dataset_id = ""
      node_pools = {
        system = {
          initial_node_count = 1
          autoscaling = {
            min_node_count = 3
            max_node_count = 6
          }
          upgrade_settings = {
            node_pool_soak_duration = "900s"
            batch_node_count        = 1
            batch_soak_duration     = "600s"
          }
          node_config = {
            image_type                     = "COS_CONTAINERD"
            machine_type                   = "e2-standard-4"
            spot                          = false
            gcfs_enabled                  = true
            gvnic_enabled                 = true
            secure_boot_enabled           = true
            integrity_monitoring_enabled   = true
            labels                        = { environment = "prod", pool = "system" }
            tags                          = ["prod", "gke-node", "system"]
            taints = [
              {
                key    = "node-pool"
                value  = "system"
                effect = "NO_SCHEDULE"
              }
            ]
          }
        }
        workload = {
          initial_node_count = 2
          autoscaling = {
            min_node_count = 3
            max_node_count = 15
          }
          upgrade_settings = {
            node_pool_soak_duration = "900s"
            batch_node_count        = 2
            batch_soak_duration     = "600s"
          }
          node_config = {
            image_type                     = "COS_CONTAINERD"
            machine_type                   = "e2-standard-8"
            spot                          = false
            gcfs_enabled                  = true
            gvnic_enabled                 = true
            secure_boot_enabled           = true
            integrity_monitoring_enabled   = true
            labels                        = { environment = "prod", pool = "workload" }
            tags                          = ["prod", "gke-node", "workload"]
            taints                        = []
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
    pod_security_policy = object({
      privileged                   = bool
      allow_privilege_escalation   = bool
      allowed_capabilities         = list(string)
      required_drop_capabilities   = list(string)
      volumes                      = list(string)
      run_as_user_rule            = string
      run_as_user_min             = number
      run_as_user_max             = number
      se_linux_rule               = string
      fs_group_rule               = string
      fs_group_min                = number
      fs_group_max                = number
    })
    create_service_account = bool
    rbac_rules = list(object({
      api_groups = list(string)
      resources  = list(string)
      verbs      = list(string)
    }))
  }))
  description = "Kubernetes namespaces configuration"
  default = {
    production = {
      labels                = { team = "platform", environment = "prod" }
      annotations           = {}
      enable_network_policy = true
      allowed_namespaces    = ["kube-system", "monitoring", "vault"]
      resource_quota = {
        "requests.cpu"      = "20"
        "requests.memory"   = "40Gi"
        "limits.cpu"        = "40"
        "limits.memory"     = "80Gi"
        "pods"              = "50"
        "services"          = "20"
        "persistentvolumeclaims" = "20"
      }
      limit_range = [
        {
          type = "Container"
          default = {
            cpu    = "500m"
            memory = "512Mi"
          }
          default_request = {
            cpu    = "100m"
            memory = "128Mi"
          }
          max = {
            cpu    = "4"
            memory = "8Gi"
          }
          min = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      ]
      pod_security_policy = {
        privileged                   = false
        allow_privilege_escalation   = false
        allowed_capabilities         = []
        required_drop_capabilities   = ["ALL"]
        volumes                      = ["configMap", "emptyDir", "projected", "secret", "downwardAPI", "persistentVolumeClaim"]
        run_as_user_rule            = "MustRunAsNonRoot"
        run_as_user_min             = 1000
        run_as_user_max             = 65535
        se_linux_rule               = "RunAsAny"
        fs_group_rule               = "RunAsAny"
        fs_group_min                = 1000
        fs_group_max                = 65535
      }
      create_service_account = true
      rbac_rules = [
        {
          api_groups = [""]
          resources  = ["pods", "services", "configmaps"]
          verbs      = ["get", "list", "create", "update", "patch"]
        }
      ]
    }
    monitoring = {
      labels                = { team = "platform", environment = "prod", component = "monitoring" }
      annotations           = {}
      enable_network_policy = true
      allowed_namespaces    = ["kube-system", "production"]
      resource_quota = {
        "requests.cpu"      = "10"
        "requests.memory"   = "20Gi"
        "limits.cpu"        = "20"
        "limits.memory"     = "40Gi"
        "pods"              = "30"
        "services"          = "15"
        "persistentvolumeclaims" = "10"
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
            memory = "4Gi"
          }
          min = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      ]
      pod_security_policy = {
        privileged                   = false
        allow_privilege_escalation   = false
        allowed_capabilities         = []
        required_drop_capabilities   = ["ALL"]
        volumes                      = ["configMap", "emptyDir", "projected", "secret", "downwardAPI", "persistentVolumeClaim"]
        run_as_user_rule            = "MustRunAsNonRoot"
        run_as_user_min             = 1000
        run_as_user_max             = 65535
        se_linux_rule               = "RunAsAny"
        fs_group_rule               = "RunAsAny"
        fs_group_min                = 1000
        fs_group_max                = 65535
      }
      create_service_account = true
      rbac_rules = [
        {
          api_groups = [""]
          resources  = ["pods", "services", "endpoints", "nodes", "nodes/proxy"]
          verbs      = ["get", "list", "watch"]
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
    cluster_name    = "prod-kafka"
    kafka_version   = "3.6.0"
    replicas        = 3
    storage_size    = "200Gi"
    storage_class   = "ssd"
    enable_connect  = true
    topics = {
      events = {
        partitions = 12
        replicas   = 3
        config = {
          "retention.ms"           = "604800000"
          "min.insync.replicas"   = "2"
          "unclean.leader.election.enable" = "false"
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
    ingress_enabled        = bool
    ingress_hosts          = list(string)
    ingress_tls           = list(any)
  })
  description = "Vault configuration"
  default = {
    namespace               = "vault"
    cluster_name           = "prod-vault"
    kms_location           = "europe-west2"
    bank_vaults_version    = "1.20.0"
    replicas               = 3
    ha_enabled             = true
    enable_workload_identity = true
    monitoring_enabled     = true
    ingress_enabled        = false
    ingress_hosts          = []
    ingress_tls           = []
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
    instance_name       = "prod-cloudsql"
    database_version   = "POSTGRES_15"
    tier              = "db-custom-4-15360"
    availability_type = "REGIONAL"
    disk_size         = 200
    k8s_namespace     = "production"
    databases         = ["app"]
    users = {
      app = {
        password = null
        password_policy = {
          allowed_failed_attempts      = 5
          password_expiration_duration = "2160h"  # 90 days
          enable_failed_attempts_check = true
          enable_password_verification = true
        }
      }
      readonly = {
        password = null
        password_policy = {
          allowed_failed_attempts      = 5
          password_expiration_duration = "2160h"  # 90 days
          enable_failed_attempts_check = true
          enable_password_verification = true
        }
      }
    }
    deploy_proxy        = true
    deletion_protection = true
  }
}

variable "enable_alloydb" {
  type        = bool
  description = "Enable AlloyDB deployment"
  default     = false
}

variable "alloydb_config" {
  type = object({
    cluster_id         = string
    database_version   = string
    display_name       = string
    k8s_namespace      = string
    primary_instance = object({
      cpu_count               = number
      availability_type       = string
      database_flags         = map(string)
      read_pool_node_count   = number
    })
    read_replica_count = number
    read_replica_config = object({
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
    cluster_id       = "prod-alloydb"
    database_version = "POSTGRES_15"
    display_name     = "Production AlloyDB Cluster"
    k8s_namespace    = "production"
    primary_instance = {
      cpu_count               = 8
      availability_type       = "REGIONAL"
      database_flags         = {
        "shared_preload_libraries" = "pg_stat_statements"
        "log_statement"           = "all"
        "log_min_duration_statement" = "1000"
      }
      read_pool_node_count   = 2
    }
    read_replica_count = 2
    read_replica_config = {
      cpu_count               = 4
      availability_type       = "ZONAL"
      database_flags         = {}
      read_pool_node_count   = 1
    }
    users = {
      app = {
        user_type      = "ALLOYDB_BUILT_IN"
        password       = null
        database_roles = ["pg_read_all_data", "pg_write_all_data"]
      }
      readonly = {
        user_type      = "ALLOYDB_BUILT_IN"
        password       = null
        database_roles = ["pg_read_all_data"]
      }
    }
    deploy_proxy = true
  }
}