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

variable "database_version" {
  type    = string
  default = "16.9"
}

variable "vpc_id" {
  type = string
}

variable "database_subnet_group_name" {
  type = string
}

variable "app_security_group_id" {
  type = string
}

variable "master_username" {
  type    = string
  default = "postgres"
}

variable "master_password" {
  type = string
}
