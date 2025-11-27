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

variable "project_domain" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "secret_prefix" {
  type = string
}

variable "ingress_class_name" {
  type = string
  default = "ingress-nginx-private"
}

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

variable dummy_saml_idp_basic_auth_user {
  type = string
  default = "someuser"
}

variable dummy_saml_idp_basic_auth_password {
  type = string
  default = "topsecret"
}
