variable "host_project_id" {
  type        = string
  description = "The ID of the host project for the shared VPC"
}

variable "service_project_ids" {
  type        = list(string)
  description = "List of service project IDs to attach to the shared VPC"
  default     = []
}

variable "network_name" {
  type        = string
  description = "Name of the shared VPC network"
}

variable "subnets" {
  type = map(object({
    name            = string
    ip_cidr_range   = string
    region          = string
    secondary_ranges = list(object({
      range_name    = string
      ip_cidr_range = string
    }))
  }))
  description = "Map of subnets to create in the shared VPC"
}