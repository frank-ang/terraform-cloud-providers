output "instance_name" {
  description = "The name of the CloudSQL instance"
  value       = google_sql_database_instance.instance.name
}

output "instance_connection_name" {
  description = "The connection name of the CloudSQL instance"
  value       = google_sql_database_instance.instance.connection_name
}

output "instance_self_link" {
  description = "The self-link of the CloudSQL instance"
  value       = google_sql_database_instance.instance.self_link
}

output "private_ip_address" {
  description = "The private IP address of the CloudSQL instance"
  value       = google_sql_database_instance.instance.private_ip_address
}

output "public_ip_address" {
  description = "The public IP address of the CloudSQL instance"
  value       = google_sql_database_instance.instance.public_ip_address
}

output "server_ca_cert" {
  description = "The CA certificate of the CloudSQL instance"
  value       = google_sql_database_instance.instance.server_ca_cert
  sensitive   = true
}

output "service_account_email" {
  description = "Email of the CloudSQL proxy service account"
  value       = google_service_account.cloudsql_proxy.email
}

output "service_account_name" {
  description = "Name of the CloudSQL proxy service account"
  value       = google_service_account.cloudsql_proxy.name
}

output "databases" {
  description = "List of created databases"
  value       = [for db in google_sql_database.database : db.name]
}

output "users" {
  description = "List of created database users"
  value       = [for user in google_sql_user.users : user.name]
}

output "k8s_secret_name" {
  description = "Name of the Kubernetes secret containing database credentials"
  value       = var.create_k8s_secret ? kubernetes_secret.db_credentials[0].metadata[0].name : null
}

output "k8s_service_account_name" {
  description = "Name of the Kubernetes service account for CloudSQL proxy"
  value       = var.create_k8s_service_account ? kubernetes_service_account.cloudsql_proxy[0].metadata[0].name : var.k8s_service_account_name
}

output "proxy_service_name" {
  description = "Name of the CloudSQL proxy Kubernetes service"
  value       = var.deploy_proxy ? kubernetes_service.cloudsql_proxy[0].metadata[0].name : null
}

output "proxy_service_endpoint" {
  description = "Endpoint for connecting to CloudSQL through the proxy"
  value       = var.deploy_proxy ? "${kubernetes_service.cloudsql_proxy[0].metadata[0].name}.${var.k8s_namespace}.svc.cluster.local:5432" : null
}

output "connection_string_template" {
  description = "Template for database connection string"
  value       = "postgresql://USERNAME:PASSWORD@${var.deploy_proxy ? "${kubernetes_service.cloudsql_proxy[0].metadata[0].name}.${var.k8s_namespace}.svc.cluster.local" : google_sql_database_instance.instance.private_ip_address}:5432/DATABASE_NAME"
}