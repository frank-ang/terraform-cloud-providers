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

# Service account for Cloud SQL Auth Proxy
resource "google_service_account" "cloudsql_proxy" {
  account_id   = "${var.instance_name}-proxy-sa"
  display_name = "CloudSQL Proxy Service Account for ${var.instance_name}"
  description  = "Service account for CloudSQL Auth Proxy"
  project      = var.project_id
}

# IAM binding for Cloud SQL Client role
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudsql_proxy.email}"
}

# Workload Identity binding
resource "google_service_account_iam_member" "workload_identity" {
  count = var.enable_workload_identity ? 1 : 0
  
  service_account_id = google_service_account.cloudsql_proxy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account_name}]"
}

# Cloud SQL instance
resource "google_sql_database_instance" "instance" {
  provider = google-beta
  
  name             = var.instance_name
  database_version = var.database_version
  region           = var.region
  project          = var.project_id
  
  deletion_protection = var.deletion_protection
  
  settings {
    tier                        = var.tier
    availability_type          = var.availability_type
    disk_type                  = var.disk_type
    disk_size                  = var.disk_size
    disk_autoresize           = var.disk_autoresize
    disk_autoresize_limit     = var.disk_autoresize_limit
    
    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = var.backup_start_time
      location                       = var.backup_location
      point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
      transaction_log_retention_days = var.transaction_log_retention_days
      backup_retention_settings {
        retained_backups = var.backup_retained_backups
        retention_unit   = "COUNT"
      }
    }
    
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                              = var.private_network
      enable_private_path_for_google_cloud_services = true
      require_ssl                                  = var.require_ssl
      
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }
    
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    
    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
    
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }
    
    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }
    
    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_window_update_track
    }
    
    insights_config {
      query_insights_enabled  = var.query_insights_enabled
      query_string_length     = var.query_string_length
      record_application_tags = var.record_application_tags
      record_client_address   = var.record_client_address
    }
    
    user_labels = var.labels
  }
  
  depends_on = [var.private_network]
}

# Database
resource "google_sql_database" "database" {
  for_each = toset(var.databases)
  
  name      = each.value
  instance  = google_sql_database_instance.instance.name
  project   = var.project_id
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

# Database users
resource "google_sql_user" "users" {
  for_each = var.users
  
  name     = each.key
  instance = google_sql_database_instance.instance.name
  project  = var.project_id
  password = each.value.password != null ? each.value.password : random_password.db_password.result
  
  dynamic "password_policy" {
    for_each = each.value.password_policy != null ? [each.value.password_policy] : []
    content {
      allowed_failed_attempts      = password_policy.value.allowed_failed_attempts
      password_expiration_duration = password_policy.value.password_expiration_duration
      enable_failed_attempts_check = password_policy.value.enable_failed_attempts_check
      enable_password_verification = password_policy.value.enable_password_verification
    }
  }
}

# Secret for database credentials
resource "kubernetes_secret" "db_credentials" {
  count = var.create_k8s_secret ? 1 : 0
  
  metadata {
    name      = "${var.instance_name}-credentials"
    namespace = var.k8s_namespace
    labels = {
      "app.kubernetes.io/name"       = "cloudsql-credentials"
      "app.kubernetes.io/instance"   = var.instance_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  data = merge(
    {
      "instance-connection-name" = google_sql_database_instance.instance.connection_name
      "private-ip"              = google_sql_database_instance.instance.private_ip_address
    },
    {
      for username, user_config in var.users :
      "${username}-password" => user_config.password != null ? user_config.password : random_password.db_password.result
    }
  )
  
  type = "Opaque"
}

# Kubernetes Service Account for Workload Identity
resource "kubernetes_service_account" "cloudsql_proxy" {
  count = var.create_k8s_service_account ? 1 : 0
  
  metadata {
    name      = var.k8s_service_account_name
    namespace = var.k8s_namespace
    annotations = merge(
      var.k8s_service_account_annotations,
      var.enable_workload_identity ? {
        "iam.gke.io/gcp-service-account" = google_service_account.cloudsql_proxy.email
      } : {}
    )
    labels = {
      "app.kubernetes.io/name"       = "cloudsql-proxy"
      "app.kubernetes.io/instance"   = var.instance_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ConfigMap for Cloud SQL Proxy configuration
resource "kubernetes_config_map" "cloudsql_proxy_config" {
  count = var.create_k8s_resources ? 1 : 0
  
  metadata {
    name      = "${var.instance_name}-proxy-config"
    namespace = var.k8s_namespace
    labels = {
      "app.kubernetes.io/name"       = "cloudsql-proxy"
      "app.kubernetes.io/instance"   = var.instance_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  data = {
    "connection-name" = google_sql_database_instance.instance.connection_name
    "port"           = "5432"
    "private-ip"     = "true"
  }
}

# Deployment for Cloud SQL Proxy (optional)
resource "kubernetes_deployment" "cloudsql_proxy" {
  count = var.deploy_proxy ? 1 : 0
  
  metadata {
    name      = "${var.instance_name}-proxy"
    namespace = var.k8s_namespace
    labels = {
      "app.kubernetes.io/name"       = "cloudsql-proxy"
      "app.kubernetes.io/instance"   = var.instance_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  spec {
    replicas = var.proxy_replicas
    
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "cloudsql-proxy"
        "app.kubernetes.io/instance" = var.instance_name
      }
    }
    
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "cloudsql-proxy"
          "app.kubernetes.io/instance" = var.instance_name
        }
      }
      
      spec {
        service_account_name = var.create_k8s_service_account ? kubernetes_service_account.cloudsql_proxy[0].metadata[0].name : var.k8s_service_account_name
        
        container {
          name  = "cloud-sql-proxy"
          image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:${var.proxy_image_tag}"
          
          args = [
            "--private-ip",
            "--port=5432",
            google_sql_database_instance.instance.connection_name
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

# Service for Cloud SQL Proxy
resource "kubernetes_service" "cloudsql_proxy" {
  count = var.deploy_proxy ? 1 : 0
  
  metadata {
    name      = "${var.instance_name}-proxy"
    namespace = var.k8s_namespace
    labels = {
      "app.kubernetes.io/name"       = "cloudsql-proxy"
      "app.kubernetes.io/instance"   = var.instance_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  spec {
    selector = {
      "app.kubernetes.io/name"     = "cloudsql-proxy"
      "app.kubernetes.io/instance" = var.instance_name
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