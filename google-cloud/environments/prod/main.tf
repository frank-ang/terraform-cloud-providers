terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "gcs" {
    bucket = var.terraform_state_bucket
    prefix = "prod/terraform/state"
  }
}

provider "google" {
  project = var.host_project_id
  region  = var.region
}

provider "google-beta" {
  project = var.host_project_id
  region  = var.region
}

data "google_client_config" "default" {}

data "google_container_cluster" "primary" {
  for_each = var.clusters
  name     = each.value.cluster_name
  location = each.value.location
  project  = each.value.project_id
  
  depends_on = [module.gke_clusters]
}

provider "kubernetes" {
  alias = "primary"
  host  = "https://${data.google_container_cluster.primary["primary"].endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.primary["primary"].master_auth[0].cluster_ca_certificate,
  )
}

provider "helm" {
  alias = "primary"
  kubernetes {
    host  = "https://${data.google_container_cluster.primary["primary"].endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.primary["primary"].master_auth[0].cluster_ca_certificate,
    )
  }
}

# Shared VPC for Production
module "shared_vpc" {
  source = "../../modules/shared-vpc"

  host_project_id      = var.host_project_id
  service_project_ids  = var.service_project_ids
  network_name         = var.network_name
  subnets             = var.subnets
}

# GKE Clusters
module "gke_clusters" {
  source = "../../modules/gke-cluster"
  
  for_each = var.clusters

  project_id                        = each.value.project_id
  cluster_name                      = each.value.cluster_name
  location                          = each.value.location
  network_self_link                 = module.shared_vpc.network_self_link
  subnetwork_self_link             = module.shared_vpc.subnets[each.value.subnet_key].self_link
  kubernetes_version               = each.value.kubernetes_version
  release_channel                  = each.value.release_channel
  deletion_protection              = each.value.deletion_protection
  enable_private_endpoint          = each.value.enable_private_endpoint
  master_ipv4_cidr_block          = each.value.master_ipv4_cidr_block
  authorized_networks             = each.value.authorized_networks
  cluster_secondary_range_name    = each.value.cluster_secondary_range_name
  services_secondary_range_name   = each.value.services_secondary_range_name
  service_account_name            = each.value.service_account_name
  service_account_roles           = each.value.service_account_roles
  node_pools                      = each.value.node_pools
  
  # Production specific settings
  cluster_autoscaling_enabled = true
  network_policy_enabled      = true
  pod_security_policy_enabled = true
  binary_authorization_evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  logging_components          = ["SYSTEM_COMPONENTS", "WORKLOADS", "API_SERVER"]
  monitoring_components       = ["SYSTEM_COMPONENTS", "WORKLOADS", "API_SERVER", "CONTROLLER_MANAGER", "SCHEDULER"]
  managed_prometheus_enabled  = true
  usage_metering_dataset_id   = each.value.usage_metering_dataset_id
}

# Namespaces
module "namespaces" {
  source = "../../modules/namespace"
  
  for_each = var.namespaces
  
  providers = {
    kubernetes = kubernetes.primary
  }

  namespace_name         = each.key
  environment           = "production"
  labels                = each.value.labels
  annotations           = each.value.annotations
  enable_network_policy = each.value.enable_network_policy
  allowed_namespaces    = each.value.allowed_namespaces
  resource_quota        = each.value.resource_quota
  limit_range          = each.value.limit_range
  pod_security_policy   = each.value.pod_security_policy
  create_service_account = each.value.create_service_account
  rbac_rules           = each.value.rbac_rules
}

# Kafka (High Availability)
module "kafka" {
  count  = var.enable_kafka ? 1 : 0
  source = "../../modules/kafka"
  
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
  }

  kafka_namespace           = var.kafka_config.namespace
  environment              = "production"
  strimzi_version          = var.kafka_config.strimzi_version
  kafka_cluster_name       = var.kafka_config.cluster_name
  kafka_version           = var.kafka_config.kafka_version
  kafka_replicas          = var.kafka_config.replicas
  kafka_storage_size      = var.kafka_config.storage_size
  storage_class           = var.kafka_config.storage_class
  kafka_topics            = var.kafka_config.topics
  kafka_users             = var.kafka_config.users
  create_kafka_connect    = var.kafka_config.enable_connect
  
  # Production specific
  operator_replicas    = 2
  zookeeper_replicas  = 3
  kafka_connect_replicas = 3
  
  # Anti-affinity for production
  kafka_affinity = {
    podAntiAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = [
        {
          labelSelector = {
            matchExpressions = [
              {
                key      = "strimzi.io/name"
                operator = "In"
                values   = ["${var.kafka_config.cluster_name}-kafka"]
              }
            ]
          }
          topologyKey = "kubernetes.io/hostname"
        }
      ]
    }
  }
  
  zookeeper_affinity = {
    podAntiAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = [
        {
          labelSelector = {
            matchExpressions = [
              {
                key      = "strimzi.io/name"
                operator = "In"
                values   = ["${var.kafka_config.cluster_name}-zookeeper"]
              }
            ]
          }
          topologyKey = "kubernetes.io/hostname"
        }
      ]
    }
  }
}

# Vault (High Availability)
module "vault" {
  count  = var.enable_vault ? 1 : 0
  source = "../../modules/vault"
  
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
    google     = google
  }

  project_id              = var.host_project_id
  vault_namespace         = var.vault_config.namespace
  environment            = "production"
  vault_cluster_name     = var.vault_config.cluster_name
  kms_location           = var.vault_config.kms_location
  bank_vaults_version    = var.vault_config.bank_vaults_version
  vault_replicas         = var.vault_config.replicas
  vault_ha_enabled       = var.vault_config.ha_enabled
  enable_workload_identity = var.vault_config.enable_workload_identity
  monitoring_enabled     = var.vault_config.monitoring_enabled
  ingress_enabled        = var.vault_config.ingress_enabled
  ingress_hosts          = var.vault_config.ingress_hosts
  ingress_tls           = var.vault_config.ingress_tls
  
  # Production specific
  vault_log_level = "INFO"
  operator_replicas = 2
  
  # Anti-affinity for production
  vault_affinity = {
    podAntiAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = [
        {
          labelSelector = {
            matchExpressions = [
              {
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["vault"]
              }
            ]
          }
          topologyKey = "kubernetes.io/hostname"
        }
      ]
    }
  }
}

# CloudSQL PostgreSQL (Optional)
module "cloudsql" {
  count  = var.enable_cloudsql ? 1 : 0
  source = "../../modules/cloudsql"
  
  providers = {
    kubernetes = kubernetes.primary
    google     = google
  }

  project_id           = var.host_project_id
  instance_name        = var.cloudsql_config.instance_name
  region              = var.region
  database_version    = var.cloudsql_config.database_version
  tier               = var.cloudsql_config.tier
  availability_type  = var.cloudsql_config.availability_type
  disk_size          = var.cloudsql_config.disk_size
  private_network    = module.shared_vpc.network_self_link
  k8s_namespace      = var.cloudsql_config.k8s_namespace
  databases          = var.cloudsql_config.databases
  users              = var.cloudsql_config.users
  deploy_proxy       = var.cloudsql_config.deploy_proxy
  deletion_protection = var.cloudsql_config.deletion_protection
  
  # Production specific
  backup_enabled = true
  point_in_time_recovery_enabled = true
  query_insights_enabled = true
  backup_retained_backups = 90
  transaction_log_retention_days = 14
  
  # High availability
  proxy_replicas = 3
  proxy_affinity = {
    podAntiAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = [
        {
          labelSelector = {
            matchExpressions = [
              {
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["cloudsql-proxy"]
              }
            ]
          }
          topologyKey = "kubernetes.io/hostname"
        }
      ]
    }
  }
}

# AlloyDB (Optional)
module "alloydb" {
  count  = var.enable_alloydb ? 1 : 0
  source = "../../modules/alloydb"
  
  providers = {
    kubernetes = kubernetes.primary
    google     = google-beta
  }

  project_id         = var.host_project_id
  cluster_id         = var.alloydb_config.cluster_id
  region            = var.region
  network_self_link = module.shared_vpc.network_self_link
  database_version  = var.alloydb_config.database_version
  display_name      = var.alloydb_config.display_name
  k8s_namespace     = var.alloydb_config.k8s_namespace
  primary_instance  = var.alloydb_config.primary_instance
  read_replica_count = var.alloydb_config.read_replica_count
  read_replica_config = var.alloydb_config.read_replica_config
  users             = var.alloydb_config.users
  deploy_proxy      = var.alloydb_config.deploy_proxy
  
  # Production specific
  backup_enabled = true
  continuous_backup_enabled = true
  backup_retention_count = 90
  continuous_backup_recovery_window_days = 30
  
  # High availability
  proxy_replicas = 3
  proxy_affinity = {
    podAntiAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = [
        {
          labelSelector = {
            matchExpressions = [
              {
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["alloydb-proxy"]
              }
            ]
          }
          topologyKey = "kubernetes.io/hostname"
        }
      ]
    }
  }
}