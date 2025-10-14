variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "project" {
  type = string
}

variable "owner" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "eks_oidc_provider_arn" {
  type = string
}

#variable "eks_oidc_provider" {
#  type = string
#}

variable "database_hostname" {
  type = string
}

variable "database_password" {
  type = string
}

variable "vault_installer_namespace" {
  type = string
  default = "tm-system"
}

variable "vault_installer_serviceaccount" {
  type = string
  default = "vault-installer"
}

variable "tm_iam_prefix" {
  type = string
}

variable "secret_prefix" {
  type = string
}
