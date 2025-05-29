variable "namespace_name" {
  type        = string
  description = "Name of the namespace to create"
}

variable "environment" {
  type        = string
  description = "Environment label for the namespace"
  default     = "development"
}

variable "labels" {
  type        = map(string)
  description = "Additional labels to add to the namespace"
  default     = {}
}

variable "annotations" {
  type        = map(string)
  description = "Annotations to add to the namespace"
  default     = {}
}

variable "enable_network_policy" {
  type        = bool
  description = "Enable network policy for namespace isolation"
  default     = true
}

variable "allowed_namespaces" {
  type        = list(string)
  description = "List of namespaces allowed to communicate with this namespace"
  default     = ["kube-system", "kube-public"]
}

variable "resource_quota" {
  type        = map(string)
  description = "Resource quota limits for the namespace"
  default     = null
}

variable "limit_range" {
  type = list(object({
    type            = string
    default         = map(string)
    default_request = map(string)
    max             = map(string)
    min             = map(string)
  }))
  description = "Limit range configuration for the namespace"
  default     = null
}

variable "pod_security_policy" {
  type = object({
    privileged                   = bool
    allow_privilege_escalation   = bool
    allowed_capabilities         = list(string)
    required_drop_capabilities   = list(string)
    volumes                      = list(string)
    run_as_user_rule            = string
    run_as_user_min             = number
    run_as_user_max             = number
    se_linux_rule               = string
    fs_group_rule               = string
    fs_group_min                = number
    fs_group_max                = number
  })
  description = "Pod Security Policy configuration"
  default     = null
}

variable "create_service_account" {
  type        = bool
  description = "Create a service account for the namespace"
  default     = true
}

variable "service_account_annotations" {
  type        = map(string)
  description = "Annotations for the service account"
  default     = {}
}

variable "automount_service_account_token" {
  type        = bool
  description = "Enable automatic mounting of the service account token"
  default     = true
}

variable "rbac_rules" {
  type = list(object({
    api_groups = list(string)
    resources  = list(string)
    verbs      = list(string)
  }))
  description = "RBAC rules for the namespace service account"
  default     = []
}