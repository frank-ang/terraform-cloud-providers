variable "project" {
  type = string
}

variable "owner" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "project_domain" {
  type = string
}

variable "tm_iam_prefix" {
  type = string
}

variable "secret_prefix" {
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
