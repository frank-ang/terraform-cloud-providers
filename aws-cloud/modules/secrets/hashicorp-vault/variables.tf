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

variable "tm_iam_prefix" {
  type = string
}

variable "secret_prefix" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "cluster_issuer" {
  type = string
}

variable "vault_installer_namespace" {
  type = string
}

variable "vault_installer_serviceaccount" {
  type = string
}
