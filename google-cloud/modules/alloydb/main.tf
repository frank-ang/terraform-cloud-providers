terraform {
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Service account for AlloyDB Auth Proxy
resource "google_service_account" "alloydb_proxy" {
  account_id   = "${var.cluster_id}-proxy-sa"
  display_name = "AlloyDB Proxy Service Account for ${var.cluster_id}"
  description  = "Service account for AlloyDB Auth Proxy"
  project      = var.project_id
}

# IAM binding for AlloyDB Client role
resource "google_project_iam_member" "alloydb_client" {
  project = var.project_id
  role    = "roles/alloydb.client"
  member  = "serviceAccount:${google_service_account.alloydb_proxy.email}"
}

# Workload Identity binding
resource "google_service_account_iam_member" "workload_identity" {
  count = var.enable_workload_identity ? 1 : 0
  
  service_account_id = google_service_account.alloydb_proxy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account_name}]"
}

# AlloyDB Cluster
resource "google_alloydb_cluster" "cluster" {
  provider = google-beta
  
  cluster_id   = var.cluster_id
  location     = var.region
  project      = var.project_id
  network_config {
    network = var.network_self_link
  }
  
  initial_user {
    user     = var.initial_user.username
    password = var.initial_user.password != null ? var.initial_user.password : random_password.db_password.result
  }
  
  automated_backup_policy {
    enabled                = var.backup_enabled
    backup_window          = var.backup_window
    location               = var.backup_location
    labels                 = var.backup_labels
    
    weekly_schedule {
      days_of_week = var.backup_days_of_week
      start_times {
        hours   = var.backup_start_hour
        minutes = var.backup_start_minute
      }
    }
    
    quantity_based_retention {
      count = var.backup_retention_count
    }
    
    encryption_config {
      kms_key_name = var.backup_encryption_key
    }
  }
  
  database_version = var.database_version
  display_name     = var.display_name
  labels          = var.labels
  
  dynamic "encryption_config" {
    for_each = var.encryption_key != null ? [1] : []
    content {
      kms_key_name = var.encryption_key
    }
  }
  
  dynamic "continuous_backup_config" {
    for_each = var.continuous_backup_enabled ? [1] : []
    content {
      enabled              = true
      recovery_window_days = var.continuous_backup_recovery_window_days
      
      dynamic "encryption_config" {
        for_each = var.continuous_backup_encryption_key != null ? [1] : []
        content {
          kms_key_name = var.continuous_backup_encryption_key
        }
      }
    }
  }
  
  deletion_policy = var.deletion_policy
}

# Primary Instance
resource "google_alloydb_instance" "primary" {
  provider = google-beta
  
  cluster       = google_alloydb_cluster.cluster.name
  instance_id   = "${var.cluster_id}-primary"
  instance_type = "PRIMARY"
  
  machine_config {
    cpu_count = var.primary_instance.cpu_count
  }
  
  database_flags = var.primary_instance.database_flags
  display_name   = "${var.display_name} Primary"
  labels        = merge(var.labels, { instance_type = "primary" })
  
  availability_type = var.primary_instance.availability_type
  
  dynamic "read_pool_config" {
    for_each = var.primary_instance.read_pool_node_count > 0 ? [1] : []
    content {
      node_count = var.primary_instance.read_pool_node_count
    }
  }
}

# Read Replicas
resource "google_alloydb_instance" "read_replicas" {
  provider = google-beta
  
  count = var.read_replica_count
  
  cluster       = google_alloydb_cluster.cluster.name
  instance_id   = "${var.cluster_id}-read-${count.index + 1}"
  instance_type = "READ_POOL"
  
  machine_config {
    cpu_count = var.read_replica_config.cpu_count
  }
  
  database_flags = var.read_replica_config.database_flags
  display_name   = "${var.display_name} Read Replica ${count.index + 1}"
  labels        = merge(var.labels, { instance_type = "read_replica" })
  
  availability_type = var.read_replica_config.availability_type
  
  read_pool_config {
    node_count = var.read_replica_config.read_pool_node_count
  }
}

# AlloyDB User
resource "google_alloydb_user" "users" {
  for_each = var.users
  
  cluster     = google_alloydb_cluster.cluster.name
  user_id     = each.key
  user_type   = each.value.user_type
  password    = each.value.password != null ? each.value.password : random_password.db_password.result
  
  database_roles = each.value.database_roles
}

# Secret for database credentials
resource "kubernetes_secret" "db_credentials" {
  count = var.create_k8s_secret ? 1 : 0
  
  metadata {
    name      = "${var.cluster_id}-credentials"
    namespace = var.k8s_namespace
    labels = {
      "app.kubernetes.io/name"       = "alloydb-credentials"
      "app.kubernetes.io/instance"   = var.cluster_id
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  data = merge(
    {
      "cluster-name"    = google_alloydb_cluster.cluster.name
      "primary-ip"      = google_alloydb_instance.primary.ip_address
    },
    {
      for username, user_config in var.users :
      "${username}-password" => user_config.password != null ? user_config.password : random_password.db_password.result
    },
    {
      "${var.initial_user.username}-password" = var.initial_user.password != null ? var.initial_user.password : random_password.db_password.result
    }
  )
  
  type = "Opaque"
}

# Kubernetes Service Account for Workload Identity
resource "kubernetes_service_account" "alloydb_proxy" {
  count = var.create_k8s_service_account ? 1 : 0
  
  metadata {
    name      = var.k8s_service_account_name
    namespace = var.k8s_namespace
    annotations = merge(
      var.k8s_service_account_annotations,
      var.enable_workload_identity ? {
        "iam.gke.io/gcp-service-account" = google_service_account.alloydb_proxy.email
      } : {}
    )
    labels = {
      "app.kubernetes.io/name"       = "alloydb-proxy"
      "app.kubernetes.io/instance"   = var.cluster_id
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ConfigMap for AlloyDB Proxy configuration
resource "kubernetes_config_map" "alloydb_proxy_config" {
  count = var.create_k8s_resources ? 1 : 0
  
  metadata {
    name      = "${var.cluster_id}-proxy-config"
    namespace = var.k8s_namespace
    labels = {
      "app.kubernetes.io/name"       = "alloydb-proxy"
      "app.kubernetes.io/instance"   = var.cluster_id
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  data = {
    "cluster-name"    = google_alloydb_cluster.cluster.name
    "primary-uri"     = "projects/${var.project_id}/locations/${var.region}/clusters/${var.cluster_id}/instances/${google_alloydb_instance.primary.instance_id}"
    "port"           = "5432"
  }
}

# Deployment for AlloyDB Proxy (optional)
resource "kubernetes_deployment" "alloydb_proxy" {
  count = var.deploy_proxy ? 1 : 0
  
  metadata {
    name      = "${var.cluster_id}-proxy"
    namespace = var.k8s_namespace
    labels = {
      "app.kubernetes.io/name"       = "alloydb-proxy"
      "app.kubernetes.io/instance"   = var.cluster_id
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  spec {
    replicas = var.proxy_replicas
    
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "alloydb-proxy"
        "app.kubernetes.io/instance" = var.cluster_id
      }
    }
    
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "alloydb-proxy"
          "app.kubernetes.io/instance" = var.cluster_id
        }
      }
      
      spec {
        service_account_name = var.create_k8s_service_account ? kubernetes_service_account.alloydb_proxy[0].metadata[0].name : var.k8s_service_account_name
        
        container {
          name  = "alloydb-proxy"
          image = "gcr.io/alloydb-connectors/alloydb-auth-proxy:${var.proxy_image_tag}"
          
          args = [
            "--port=5432",
            "projects/${var.project_id}/locations/${var.region}/clusters/${var.cluster_id}/instances/${google_alloydb_instance.primary.instance_id}"
          ]
          
          port {
            name           = "postgres"
            container_port = 5432
            protocol       = "TCP"
          }
          
          resources {
            limits = {
              memory = var.proxy_resources.limits.memory
              cpu    = var.proxy_resources.limits.cpu
            }
            requests = {
              memory = var.proxy_resources.requests.memory
              cpu    = var.proxy_resources.requests.cpu
            }
          }
          
          security_context {
            run_as_non_root             = true
            run_as_user                 = 65532
            allow_privilege_escalation  = false
            read_only_root_filesystem   = true
          }
          
          liveness_probe {
            tcp_socket {
              port = 5432
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
          
          readiness_probe {
            tcp_socket {
              port = 5432
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }
        
        dynamic "toleration" {
          for_each = var.proxy_tolerations
          content {
            key      = toleration.value.key
            operator = toleration.value.operator
            value    = toleration.value.value
            effect   = toleration.value.effect
          }
        }
        
        dynamic "affinity" {
          for_each = var.proxy_affinity != null ? [var.proxy_affinity] : []
          content {
            dynamic "node_affinity" {
              for_each = affinity.value.node_affinity != null ? [affinity.value.node_affinity] : []
              content {
                dynamic "required_during_scheduling_ignored_during_execution" {
                  for_each = node_affinity.value.required_during_scheduling_ignored_during_execution != null ? [node_affinity.value.required_during_scheduling_ignored_during_execution] : []
                  content {
                    dynamic "node_selector_term" {
                      for_each = required_during_scheduling_ignored_during_execution.value.node_selector_terms
                      content {
                        dynamic "match_expressions" {
                          for_each = node_selector_term.value.match_expressions != null ? node_selector_term.value.match_expressions : []
                          content {
                            key      = match_expressions.value.key
                            operator = match_expressions.value.operator
                            values   = match_expressions.value.values
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        
        node_selector = var.proxy_node_selector
      }
    }
  }
}

# Service for AlloyDB Proxy
resource "kubernetes_service" "alloydb_proxy" {
  count = var.deploy_proxy ? 1 : 0
  
  metadata {
    name      = "${var.cluster_id}-proxy"
    namespace = var.k8s_namespace
    labels = {
      "app.kubernetes.io/name"       = "alloydb-proxy"
      "app.kubernetes.io/instance"   = var.cluster_id
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  spec {
    selector = {
      "app.kubernetes.io/name"     = "alloydb-proxy"
      "app.kubernetes.io/instance" = var.cluster_id
    }
    
    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
    
    type = "ClusterIP"
  }
}