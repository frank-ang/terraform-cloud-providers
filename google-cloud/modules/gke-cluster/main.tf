module "enabled_google_apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.0"

  project_id                  = var.project_id
  disable_services_on_destroy = false

  activate_apis = [
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "secretmanager.googleapis.com",
    "gkehub.googleapis.com",
    "mesh.googleapis.com",
    "clouddns.googleapis.com",
    "artifactregistry.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "binaryauthorization.googleapis.com",
    "networkconnectivity.googleapis.com",
    "iap.googleapis.com",
    "alloydb.googleapis.com"
  ]
}

module "gke_service_account" {
  source  = "gruntwork-io/gke/google//modules/gke-service-account"
  version = "0.10.0"

  name        = var.service_account_name
  project     = var.project_id
  description = "Service Account used for node pool communication"
}

locals {
  all_service_account_roles = concat(var.service_account_roles, [
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/secretmanager.secretAccessor"
  ])
}

resource "google_project_iam_member" "service_account_roles" {
  for_each = toset(local.all_service_account_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${module.gke_service_account.email}"

  depends_on = [module.gke_service_account]
}

resource "google_container_cluster" "cluster" {
  provider = google-beta

  project    = var.project_id
  name       = var.cluster_name
  location   = var.location
  network    = var.network_self_link
  subnetwork = var.subnetwork_self_link

  min_master_version  = var.kubernetes_version
  deletion_protection = var.deletion_protection

  initial_node_count       = 1
  remove_default_node_pool = true

  release_channel {
    channel = var.release_channel
  }

  private_cluster_config {
    enable_private_endpoint = var.enable_private_endpoint
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.cluster_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  cluster_autoscaling {
    enabled             = var.cluster_autoscaling_enabled
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    
    dynamic "resource_limits" {
      for_each = var.cluster_autoscaling_resource_limits
      content {
        resource_type = resource_limits.value.resource_type
        minimum       = resource_limits.value.minimum
        maximum       = resource_limits.value.maximum
      }
    }

    auto_provisioning_defaults {
      service_account = module.gke_service_account.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }

  # Kubernetes API Configuration
  dynamic "addons_config" {
    for_each = var.addons_config != null ? [var.addons_config] : []
    content {
      http_load_balancing {
        disabled = addons_config.value.http_load_balancing_disabled
      }
      horizontal_pod_autoscaling {
        disabled = addons_config.value.horizontal_pod_autoscaling_disabled
      }
      network_policy_config {
        disabled = addons_config.value.network_policy_disabled
      }
      gcp_filestore_csi_driver_config {
        enabled = addons_config.value.filestore_csi_driver_enabled
      }
      gce_persistent_disk_csi_driver_config {
        enabled = addons_config.value.gce_pd_csi_driver_enabled
      }
    }
  }

  # Network Policy
  network_policy {
    enabled  = var.network_policy_enabled
    provider = var.network_policy_enabled ? "CALICO" : null
  }

  # Pod Security Policy
  pod_security_policy_config {
    enabled = var.pod_security_policy_enabled
  }

  # Binary Authorization
  binary_authorization {
    evaluation_mode = var.binary_authorization_evaluation_mode
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Resource Usage Export
  resource_usage_export_config {
    enable_network_egress_metering       = true
    enable_resource_consumption_metering = true
    
    bigquery_destination {
      dataset_id = var.usage_metering_dataset_id
    }
  }

  # Logging and Monitoring
  logging_config {
    enable_components = var.logging_components
  }

  monitoring_config {
    enable_components = var.monitoring_components
    
    managed_prometheus {
      enabled = var.managed_prometheus_enabled
    }
  }

  depends_on = [module.enabled_google_apis]
}

# Default Node Pool
resource "google_container_node_pool" "default_pool" {
  for_each = var.node_pools

  provider = google-beta

  name     = each.key
  project  = var.project_id
  cluster  = google_container_cluster.cluster.name
  location = google_container_cluster.cluster.location

  initial_node_count = each.value.initial_node_count

  dynamic "autoscaling" {
    for_each = each.value.autoscaling != null ? [each.value.autoscaling] : []
    content {
      min_node_count = autoscaling.value.min_node_count
      max_node_count = autoscaling.value.max_node_count
    }
  }

  upgrade_settings {
    strategy = "BLUE_GREEN"
    blue_green_settings {
      node_pool_soak_duration = each.value.upgrade_settings.node_pool_soak_duration
      standard_rollout_policy {
        batch_node_count    = each.value.upgrade_settings.batch_node_count
        batch_soak_duration = each.value.upgrade_settings.batch_soak_duration
      }
    }
  }

  node_config {
    image_type      = each.value.node_config.image_type
    machine_type    = each.value.node_config.machine_type
    service_account = module.gke_service_account.email
    spot            = each.value.node_config.spot

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    dynamic "taint" {
      for_each = each.value.node_config.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    gcfs_config {
      enabled = each.value.node_config.gcfs_enabled
    }

    gvnic {
      enabled = each.value.node_config.gvnic_enabled
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = each.value.node_config.secure_boot_enabled
      enable_integrity_monitoring = each.value.node_config.integrity_monitoring_enabled
    }

    labels = each.value.node_config.labels
    tags   = each.value.node_config.tags
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}