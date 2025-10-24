variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "project" {
  type = string
}

variable "project_domain" {
  type = string
}

variable "owner" {
  type = string
}

variable ingress_class_name { # DEPRECATED
  type = string
}

variable "kafka_version" {
  type = string
  default = "3.9.0"
}

variable "kafka_broker_replicas" {
  type    = number
  default = 3
}

variable "kafka_topc_replication_factor" {
  type    = number
  default = 3
}

variable "cert_manager_selfsigned_cluster_issuer" {
  type = string
}