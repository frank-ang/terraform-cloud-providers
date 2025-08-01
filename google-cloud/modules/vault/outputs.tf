output "vault_namespace" {
  description = "Namespace where Vault is deployed"
  value       = var.vault_namespace
}

output "vault_cluster_name" {
  description = "Name of the Vault cluster"
  value       = var.vault_cluster_name
}

output "vault_service_url" {
  description = "Internal service URL for Vault"
  value       = var.create_vault_instance ? "https://${var.vault_cluster_name}.${var.vault_namespace}.svc.cluster.local:8200" : null
}

output "kms_key_ring_name" {
  description = "Name of the KMS key ring"
  value       = google_kms_key_ring.vault.name
}

output "kms_crypto_key_name" {
  description = "Name of the KMS crypto key"
  value       = google_kms_crypto_key.vault_unseal.name
}

output "kms_crypto_key_id" {
  description = "ID of the KMS crypto key"
  value       = google_kms_crypto_key.vault_unseal.id
}

output "vault_kms_service_account_email" {
  description = "Email of the Vault KMS service account"
  value       = google_service_account.vault_kms.email
}

output "vault_service_account_name" {
  description = "Name of the Vault Kubernetes service account"
  value       = var.vault_service_account_name
}

output "bank_vaults_version" {
  description = "Version of the Bank Vaults operator"
  value       = var.bank_vaults_version
}

output "vault_image" {
  description = "Vault container image"
  value       = "${var.vault_image_repository}:${var.vault_image_tag}"
}

output "tls_secret_name" {
  description = "Name of the TLS secret"
  value       = var.tls_secret_name
}