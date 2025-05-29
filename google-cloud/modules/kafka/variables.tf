variable "kafka_namespace" {
  type        = string
  description = "Namespace for Kafka deployment"
  default     = "kafka"
}

variable "create_namespace" {
  type        = bool
  description = "Create the Kafka namespace"
  default     = true
}

variable "environment" {
  type        = string
  description = "Environment label"
  default     = "development"
}

variable "strimzi_version" {
  type        = string
  description = "Version of Strimzi operator to install"
  default     = "0.38.0"
}

variable "image_registry" {
  type        = string
  description = "Container image registry"
  default     = "quay.io"
}

variable "operator_replicas" {
  type        = number
  description = "Number of Strimzi operator replicas"
  default     = 1
}

variable "operator_resources" {
  type = object({
    limits = object({
      memory = string
      cpu    = string
    })
    requests = object({
      memory = string
      cpu    = string
    })
  })
  description = "Resource limits and requests for the Strimzi operator"
  default = {
    limits = {
      memory = "384Mi"
      cpu    = "1000m"
    }
    requests = {
      memory = "384Mi"
      cpu    = "200m"
    }
  }
}

variable "watch_namespaces" {
  type        = list(string)
  description = "List of namespaces the operator should watch"
  default     = []
}

variable "create_global_resources" {
  type        = bool
  description = "Create global resources like ClusterRoles"
  default     = true
}

variable "operator_tolerations" {
  type        = list(any)
  description = "Tolerations for the operator pods"
  default     = []
}

variable "operator_affinity" {
  type        = any
  description = "Affinity rules for the operator pods"
  default     = {}
}

variable "operator_node_selector" {
  type        = map(string)
  description = "Node selector for the operator pods"
  default     = {}
}

variable "create_kafka_cluster" {
  type        = bool
  description = "Create a Kafka cluster"
  default     = true
}

variable "kafka_cluster_name" {
  type        = string
  description = "Name of the Kafka cluster"
  default     = "kafka-cluster"
}

variable "kafka_version" {
  type        = string
  description = "Kafka version"
  default     = "3.6.0"
}

variable "kafka_replicas" {
  type        = number
  description = "Number of Kafka broker replicas"
  default     = 3
}

variable "kafka_config" {
  type        = map(any)
  description = "Additional Kafka configuration"
  default     = {}
}

variable "kafka_storage_size" {
  type        = string
  description = "Storage size for Kafka brokers"
  default     = "100Gi"
}

variable "storage_class" {
  type        = string
  description = "Storage class for persistent volumes"
  default     = "standard-rwo"
}

variable "kafka_resources" {
  type = object({
    limits = object({
      memory = string
      cpu    = string
    })
    requests = object({
      memory = string
      cpu    = string
    })
  })
  description = "Resource limits and requests for Kafka brokers"
  default = {
    limits = {
      memory = "2Gi"
      cpu    = "1000m"
    }
    requests = {
      memory = "2Gi"
      cpu    = "500m"
    }
  }
}

variable "kafka_jvm_options" {
  type = object({
    "-Xms" = string
    "-Xmx" = string
  })
  description = "JVM options for Kafka brokers"
  default = {
    "-Xms" = "1024m"
    "-Xmx" = "1024m"
  }
}

variable "kafka_tolerations" {
  type        = list(any)
  description = "Tolerations for Kafka pods"
  default     = []
}

variable "kafka_affinity" {
  type        = any
  description = "Affinity rules for Kafka pods"
  default     = {}
}

variable "kafka_node_selector" {
  type        = map(string)
  description = "Node selector for Kafka pods"
  default     = {}
}

variable "zookeeper_replicas" {
  type        = number
  description = "Number of Zookeeper replicas"
  default     = 3
}

variable "zookeeper_storage_size" {
  type        = string
  description = "Storage size for Zookeeper"
  default     = "10Gi"
}

variable "zookeeper_resources" {
  type = object({
    limits = object({
      memory = string
      cpu    = string
    })
    requests = object({
      memory = string
      cpu    = string
    })
  })
  description = "Resource limits and requests for Zookeeper"
  default = {
    limits = {
      memory = "1Gi"
      cpu    = "500m"
    }
    requests = {
      memory = "1Gi"
      cpu    = "250m"
    }
  }
}

variable "zookeeper_jvm_options" {
  type = object({
    "-Xms" = string
    "-Xmx" = string
  })
  description = "JVM options for Zookeeper"
  default = {
    "-Xms" = "512m"
    "-Xmx" = "512m"
  }
}

variable "zookeeper_tolerations" {
  type        = list(any)
  description = "Tolerations for Zookeeper pods"
  default     = []
}

variable "zookeeper_affinity" {
  type        = any
  description = "Affinity rules for Zookeeper pods"
  default     = {}
}

variable "zookeeper_node_selector" {
  type        = map(string)
  description = "Node selector for Zookeeper pods"
  default     = {}
}

variable "entity_operator_resources" {
  type = object({
    limits = object({
      memory = string
      cpu    = string
    })
    requests = object({
      memory = string
      cpu    = string
    })
  })
  description = "Resource limits and requests for Entity Operator"
  default = {
    limits = {
      memory = "512Mi"
      cpu    = "500m"
    }
    requests = {
      memory = "512Mi"
      cpu    = "100m"
    }
  }
}

variable "kafka_topics" {
  type = map(object({
    partitions = number
    replicas   = number
    config     = map(any)
  }))
  description = "Kafka topics to create"
  default     = {}
}

variable "kafka_users" {
  type = map(object({
    authentication_type = string
    acls = list(object({
      resource = object({
        type = string
        name = string
        patternType = string
      })
      operation = string
      host = string
    }))
  }))
  description = "Kafka users to create"
  default     = {}
}

variable "create_kafka_connect" {
  type        = bool
  description = "Create Kafka Connect cluster"
  default     = false
}

variable "kafka_connect_replicas" {
  type        = number
  description = "Number of Kafka Connect replicas"
  default     = 3
}

variable "kafka_connect_config" {
  type        = map(any)
  description = "Additional Kafka Connect configuration"
  default     = {}
}

variable "kafka_connect_resources" {
  type = object({
    limits = object({
      memory = string
      cpu    = string
    })
    requests = object({
      memory = string
      cpu    = string
    })
  })
  description = "Resource limits and requests for Kafka Connect"
  default = {
    limits = {
      memory = "2Gi"
      cpu    = "1000m"
    }
    requests = {
      memory = "2Gi"
      cpu    = "500m"
    }
  }
}

variable "kafka_connect_tolerations" {
  type        = list(any)
  description = "Tolerations for Kafka Connect pods"
  default     = []
}

variable "kafka_connect_affinity" {
  type        = any
  description = "Affinity rules for Kafka Connect pods"
  default     = {}
}

variable "kafka_connect_node_selector" {
  type        = map(string)
  description = "Node selector for Kafka Connect pods"
  default     = {}
}