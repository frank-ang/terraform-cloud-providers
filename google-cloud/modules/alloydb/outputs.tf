output "cluster_name" {
  description = "The name of the AlloyDB cluster"
  value       = google_alloydb_cluster.cluster.name
}

output "cluster_id" {
  description = "The ID of the AlloyDB cluster"
  value       = google_alloydb_cluster.cluster.cluster_id
}

output "cluster_uid" {
  description = "The UID of the AlloyDB cluster"
  value       = google_alloydb_cluster.cluster.uid
}

output "primary_instance_name" {
  description = "The name of the primary AlloyDB instance"
  value       = google_alloydb_instance.primary.name
}

output "primary_instance_id" {
  description = "The ID of the primary AlloyDB instance"
  value       = google_alloydb_instance.primary.instance_id
}

output "primary_instance_ip" {
  description = "The IP address of the primary AlloyDB instance"
  value       = google_alloydb_instance.primary.ip_address
}

output "primary_instance_uri" {
  description = "The URI of the primary AlloyDB instance"
  value       = "projects/${var.project_id}/locations/${var.region}/clusters/${var.cluster_id}/instances/${google_alloydb_instance.primary.instance_id}"
}

output "read_replica_instances" {
  description = "List of read replica instance details"
  value = [
    for replica in google_alloydb_instance.read_replicas : {
      name       = replica.name
      instance_id = replica.instance_id
      ip_address = replica.ip_address
    }
  ]
}

output "service_account_email" {
  description = "Email of the AlloyDB proxy service account"
  value       = google_service_account.alloydb_proxy.email
}

output "service_account_name" {
  description = "Name of the AlloyDB proxy service account"
  value       = google_service_account.alloydb_proxy.name
}

output "users" {
  description = "List of created AlloyDB users"
  value       = [for user in google_alloydb_user.users : user.user_id]
}

output "k8s_secret_name" {
  description = "Name of the Kubernetes secret containing database credentials"
  value       = var.create_k8s_secret ? kubernetes_secret.db_credentials[0].metadata[0].name : null
}

output "k8s_service_account_name" {
  description = "Name of the Kubernetes service account for AlloyDB proxy"
  value       = var.create_k8s_service_account ? kubernetes_service_account.alloydb_proxy[0].metadata[0].name : var.k8s_service_account_name
}

output "proxy_service_name" {
  description = "Name of the AlloyDB proxy Kubernetes service"
  value       = var.deploy_proxy ? kubernetes_service.alloydb_proxy[0].metadata[0].name : null
}

output "proxy_service_endpoint" {
  description = "Endpoint for connecting to AlloyDB through the proxy"
  value       = var.deploy_proxy ? "${kubernetes_service.alloydb_proxy[0].metadata[0].name}.${var.k8s_namespace}.svc.cluster.local:5432" : null
}

output "connection_string_template" {
  description = "Template for database connection string"
  value       = "postgresql://USERNAME:PASSWORD@${var.deploy_proxy ? "${kubernetes_service.alloydb_proxy[0].metadata[0].name}.${var.k8s_namespace}.svc.cluster.local" : google_alloydb_instance.primary.ip_address}:5432/postgres"
}

output "backup_schedule" {
  description = "Backup schedule configuration"
  value = {
    enabled          = var.backup_enabled
    days_of_week     = var.backup_days_of_week
    start_time       = "${var.backup_start_hour}:${format("%02d", var.backup_start_minute)}"
    retention_count  = var.backup_retention_count
  }
}