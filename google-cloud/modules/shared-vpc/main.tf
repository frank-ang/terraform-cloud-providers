resource "google_compute_network" "shared_vpc" {
  project                         = var.host_project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
}

resource "google_compute_shared_vpc_host_project" "host" {
  project = var.host_project_id
}

resource "google_compute_shared_vpc_service_project" "service" {
  for_each        = toset(var.service_project_ids)
  host_project    = var.host_project_id
  service_project = each.value
  depends_on      = [google_compute_shared_vpc_host_project.host]
}

resource "google_compute_subnetwork" "cluster_subnet" {
  for_each                 = var.subnets
  project                  = var.host_project_id
  name                     = each.value.name
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  network                  = google_compute_network.shared_vpc.id
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "router" {
  for_each = var.subnets
  name     = "${each.value.name}-router"
  region   = each.value.region
  network  = google_compute_network.shared_vpc.id
  project  = var.host_project_id
}

resource "google_compute_router_nat" "nat" {
  for_each                           = var.subnets
  name                               = "${each.value.name}-nat"
  router                             = google_compute_router.router[each.key].name
  region                             = each.value.region
  project                            = var.host_project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_project_service" "service_networking" {
  project            = var.host_project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.network_name}-private-ip"
  project       = var.host_project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.shared_vpc.id
}

resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.shared_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}