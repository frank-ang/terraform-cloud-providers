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

variable private_subnet_ids {
  type = list(string)
}

variable app_security_group_id {
  type = string
}

variable "kafka_version" {
  type = string
  default = "3.9.x"
}

variable "kafka_broker_replicas" {
  type    = number
  default = 3
}

variable "kafka_topc_replication_factor" {
  type    = number
  default = 3
}
