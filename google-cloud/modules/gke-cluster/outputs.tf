output "cluster_id" {
  description = "An identifier for the cluster with format projects/{{project}}/locations/{{location}}/clusters/{{name}}"
  value       = google_container_cluster.cluster.id
}

output "cluster_name" {
  description = "Cluster name"
  value       = google_container_cluster.cluster.name
}

output "cluster_location" {
  description = "Cluster location (region if regional cluster, zone if zonal cluster)"
  value       = google_container_cluster.cluster.location
}

output "cluster_endpoint" {
  description = "Cluster endpoint"
  value       = google_container_cluster.cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster ca certificate (base64 encoded)"
  value       = google_container_cluster.cluster.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "service_account_email" {
  description = "The email of the service account used for nodes"
  value       = module.gke_service_account.email
}

output "node_pools" {
  description = "List of node pools associated with this cluster"
  value = {
    for k, v in google_container_node_pool.default_pool : k => {
      name               = v.name
      location           = v.location
      initial_node_count = v.initial_node_count
    }
  }
}