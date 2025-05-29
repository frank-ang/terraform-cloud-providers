output "namespace_name" {
  description = "Name of the created namespace"
  value       = kubernetes_namespace.namespace.metadata[0].name
}

output "namespace_uid" {
  description = "UID of the created namespace"
  value       = kubernetes_namespace.namespace.metadata[0].uid
}

output "service_account_name" {
  description = "Name of the created service account"
  value       = var.create_service_account ? kubernetes_service_account.namespace_sa[0].metadata[0].name : null
}

output "labels" {
  description = "Labels applied to the namespace"
  value       = kubernetes_namespace.namespace.metadata[0].labels
}