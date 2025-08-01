terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Create namespace for Kafka
resource "kubernetes_namespace" "kafka" {
  count = var.create_namespace ? 1 : 0
  
  metadata {
    name = var.kafka_namespace
    labels = {
      name         = var.kafka_namespace
      managed-by   = "terraform"
      component    = "kafka"
      environment  = var.environment
    }
  }
}

# Install Strimzi Kafka Operator
resource "helm_release" "strimzi_operator" {
  name       = "strimzi-kafka-operator"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = var.strimzi_version
  namespace  = var.kafka_namespace

  values = [yamlencode({
    image = {
      registry = var.image_registry
    }
    
    replicas = var.operator_replicas
    
    resources = var.operator_resources
    
    watchNamespaces = var.watch_namespaces
    
    createGlobalResources = var.create_global_resources
    
    tolerations = var.operator_tolerations
    
    affinity = var.operator_affinity
    
    nodeSelector = var.operator_node_selector
  })]

  depends_on = [kubernetes_namespace.kafka]
}

# Kafka Cluster Custom Resource
resource "kubernetes_manifest" "kafka_cluster" {
  count = var.create_kafka_cluster ? 1 : 0
  
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "Kafka"
    
    metadata = {
      name      = var.kafka_cluster_name
      namespace = var.kafka_namespace
      labels = {
        environment = var.environment
        managed-by  = "terraform"
      }
    }
    
    spec = {
      kafka = {
        version  = var.kafka_version
        replicas = var.kafka_replicas
        
        listeners = [
          {
            name = "plain"
            port = 9092
            type = "internal"
            tls  = false
          },
          {
            name = "tls"
            port = 9093
            type = "internal"
            tls  = true
          }
        ]
        
        config = merge(
          {
            "offsets.topic.replication.factor"         = min(var.kafka_replicas, 3)
            "transaction.state.log.replication.factor" = min(var.kafka_replicas, 3)
            "transaction.state.log.min.isr"           = min(var.kafka_replicas, 2)
            "default.replication.factor"              = min(var.kafka_replicas, 3)
            "min.insync.replicas"                     = min(var.kafka_replicas, 2)
            "inter.broker.protocol.version"           = var.kafka_version
          },
          var.kafka_config
        )
        
        storage = {
          type = "persistent-claim"
          size = var.kafka_storage_size
          class = var.storage_class
        }
        
        resources = var.kafka_resources
        
        jvmOptions = var.kafka_jvm_options
        
        template = {
          pod = {
            tolerations  = var.kafka_tolerations
            affinity     = var.kafka_affinity
            nodeSelector = var.kafka_node_selector
            
            securityContext = {
              runAsUser    = 1001
              runAsGroup   = 1001
              fsGroup      = 1001
              runAsNonRoot = true
            }
          }
          
          persistentVolumeClaim = {
            metadata = {
              labels = {
                component = "kafka-storage"
              }
            }
          }
        }
      }
      
      zookeeper = {
        replicas = var.zookeeper_replicas
        
        storage = {
          type = "persistent-claim"
          size = var.zookeeper_storage_size
          class = var.storage_class
        }
        
        resources = var.zookeeper_resources
        
        jvmOptions = var.zookeeper_jvm_options
        
        template = {
          pod = {
            tolerations  = var.zookeeper_tolerations
            affinity     = var.zookeeper_affinity
            nodeSelector = var.zookeeper_node_selector
            
            securityContext = {
              runAsUser    = 1001
              runAsGroup   = 1001
              fsGroup      = 1001
              runAsNonRoot = true
            }
          }
        }
      }
      
      entityOperator = {
        topicOperator = {
          resources = var.entity_operator_resources
        }
        userOperator = {
          resources = var.entity_operator_resources
        }
      }
    }
  }
  
  depends_on = [helm_release.strimzi_operator]
}

# Kafka Topics
resource "kubernetes_manifest" "kafka_topics" {
  for_each = var.kafka_topics
  
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "KafkaTopic"
    
    metadata = {
      name      = each.key
      namespace = var.kafka_namespace
      labels = {
        "strimzi.io/cluster" = var.kafka_cluster_name
        environment          = var.environment
        managed-by          = "terraform"
      }
    }
    
    spec = {
      partitions = each.value.partitions
      replicas   = each.value.replicas
      config     = each.value.config
    }
  }
  
  depends_on = [kubernetes_manifest.kafka_cluster]
}

# Kafka Users
resource "kubernetes_manifest" "kafka_users" {
  for_each = var.kafka_users
  
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "KafkaUser"
    
    metadata = {
      name      = each.key
      namespace = var.kafka_namespace
      labels = {
        "strimzi.io/cluster" = var.kafka_cluster_name
        environment          = var.environment
        managed-by          = "terraform"
      }
    }
    
    spec = {
      authentication = {
        type = each.value.authentication_type
      }
      
      authorization = {
        type = "simple"
        acls = each.value.acls
      }
    }
  }
  
  depends_on = [kubernetes_manifest.kafka_cluster]
}

# Kafka Connect (Optional)
resource "kubernetes_manifest" "kafka_connect" {
  count = var.create_kafka_connect ? 1 : 0
  
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "KafkaConnect"
    
    metadata = {
      name      = "${var.kafka_cluster_name}-connect"
      namespace = var.kafka_namespace
      annotations = {
        "strimzi.io/use-connector-resources" = "true"
      }
      labels = {
        environment = var.environment
        managed-by  = "terraform"
      }
    }
    
    spec = {
      version  = var.kafka_version
      replicas = var.kafka_connect_replicas
      
      bootstrapServers = "${var.kafka_cluster_name}-kafka-bootstrap:9093"
      
      tls = {
        trustedCertificates = [
          {
            secretName = "${var.kafka_cluster_name}-cluster-ca-cert"
            certificate = "ca.crt"
          }
        ]
      }
      
      config = merge(
        {
          "group.id"                           = "connect-cluster"
          "offset.storage.topic"               = "connect-cluster-offsets"
          "config.storage.topic"               = "connect-cluster-configs"
          "status.storage.topic"               = "connect-cluster-status"
          "config.storage.replication.factor"  = min(var.kafka_replicas, 3)
          "offset.storage.replication.factor"  = min(var.kafka_replicas, 3)
          "status.storage.replication.factor"  = min(var.kafka_replicas, 3)
        },
        var.kafka_connect_config
      )
      
      resources = var.kafka_connect_resources
      
      template = {
        pod = {
          tolerations  = var.kafka_connect_tolerations
          affinity     = var.kafka_connect_affinity
          nodeSelector = var.kafka_connect_node_selector
        }
      }
    }
  }
  
  depends_on = [kubernetes_manifest.kafka_cluster]
}