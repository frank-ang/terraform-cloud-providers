output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.shared_vpc.id
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.shared_vpc.name
}

output "network_self_link" {
  description = "The URI of the VPC network"
  value       = google_compute_network.shared_vpc.self_link
}

output "subnets" {
  description = "A map of subnet names to subnet IDs"
  value = {
    for k, v in google_compute_subnetwork.cluster_subnet : k => {
      id        = v.id
      self_link = v.self_link
      name      = v.name
      region    = v.region
    }
  }
}