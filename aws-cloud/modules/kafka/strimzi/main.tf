# https://strimzi.io/quickstarts/
terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

provider "kubernetes" {
    config_path = "~/.kube/config"
}

provider "kubectl" {
  config_path = "~/.kube/config" 
}

provider "helm" {
    kubernetes = {
      config_path = "~/.kube/config"
    }
}

locals {
  kafka_namespace             = "kafka"
  kafka_name                  = "kafka-${var.project}"
  kafka_subdomain             = "${local.kafka_namespace}.${var.project_domain}"
  kafka_broker_hostnames      = formatlist("kafka-%s.${local.kafka_subdomain}", range(var.kafka_broker_replicas))
  kafka_bootstrap_hostname    = "bootstrap.${local.kafka_subdomain}"
  kafka_broker_internal_cert  = "kafka-broker-internal-cert"
  kafka_broker_internal_ca    = "kafka-broker-internal-ca"
  kafka_external_port         = 9093
  sasl_scram_test_secret_name = "sasl-scram-test-secret"
  sasl_scram_test_secret_password_field = "password"
  sasl_scram_test_secret = {
    username = "sasl-scram-test-user"
    password = "sasl-scram-test-password"
  }
  base64_sasl_scram_test_secret_password = base64encode(local.sasl_scram_test_secret.password)
  strimzi_kafka_ssl_dir_path = "/strimzi-kafka-certs"
}

# CRDs are upgraded outside of helm.
resource "helm_release" "strimzi" {
  depends_on = [
    kubernetes_namespace.kafka
  ]
  count = 1
  name       = "strimzi-cluster-operator"
  repository = "oci://quay.io/strimzi-helm/"
  chart      = "strimzi-kafka-operator"
  namespace  = local.kafka_namespace
  create_namespace = true
  version    = "0.45.1" # Strimzi 0.45 is the last minor Strimzi version with support for ZooKeeper
  set = [
    {
      name  = "replicas"
      value = 1
    },
    {
      name  = "watchAnyNamespace"
      value = true
    }
  ]
}

resource "kubernetes_namespace" "kafka" {
  metadata {
    name = local.kafka_namespace
  }
}

resource "kubectl_manifest" "kafka_nodepool" {
  count = 1
  depends_on = [
    helm_release.strimzi,
  ]
  yaml_body = <<-EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: pool
  namespace: ${local.kafka_namespace}
  labels:
    strimzi.io/cluster: ${local.kafka_name}
spec:
  replicas: 3
  roles:
    - broker
  storage:
    type: persistent-claim
    size: 30Gi
    deleteClaim: true
    kraftMetadata: shared
    class: gp2
EOF
}

resource "kubectl_manifest" "kafka_cluster" {
  count = 1
  depends_on = [
    helm_release.strimzi, kubectl_manifest.kafka_nodepool, kubectl_manifest.kafka_broker_internal_cert
  ]
  yaml_body = <<-EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: ${local.kafka_name}
  namespace: ${local.kafka_namespace}
  annotations:
    strimzi.io/node-pools: enabled
spec:
  kafka:
    version: ${var.kafka_version}
    replicas: ${var.kafka_broker_replicas}
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9095
        type: internal
        tls: true
        authentication:
          type: tls
        configuration:
          brokerCertChainAndKey:
            secretName: ${local.kafka_broker_internal_cert}
            certificate: tls.crt
            key: tls.key
      - name: scram
        port: 9097
        type: internal
        tls: true
        authentication:
          type: scram-sha-512
        configuration:
          brokerCertChainAndKey:
            secretName: ${local.kafka_broker_internal_cert}
            certificate: tls.crt
            key: tls.key
      - name: external
        port: ${local.kafka_external_port}
        type: ingress
        tls: true
        authentication:
          type: scram-sha-512
        configuration:
          class: ${local.ingress_nginx_ingress_class}
          bootstrap:
            host: ${local.kafka_bootstrap_hostname}
            alternativeNames:
            - kafka
            - ${local.kafka_name}-kafka-bootstrap.${local.kafka_namespace}.svc.cluster.local
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.kafka_bootstrap_hostname}
          brokers:
          - broker: 0
            host: ${local.kafka_broker_hostnames[0]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.kafka_broker_hostnames[0]}
          - broker: 1
            host: ${local.kafka_broker_hostnames[1]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.kafka_broker_hostnames[1]}
          - broker: 2
            host:  ${local.kafka_broker_hostnames[2]}
            annotations:
              kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
              external-dns.alpha.kubernetes.io/hostname: ${local.kafka_broker_hostnames[2]}
          brokerCertChainAndKey:
            secretName: ${local.kafka_broker_internal_cert}
            certificate: tls.crt
            key: tls.key
    config:
      message.max.bytes: 4194304
      replica.fetch.max.bytes: 5242880
      unclean.leader.election.enable: false
      min.insync.replicas: 2
      log.message.timestamp.type: CreateTime
      offsets.topic.replication.factor: ${var.kafka_topc_replication_factor}
      default.replication.factor: ${var.kafka_topc_replication_factor}
      offsets.retention.minutes: 20160
      auto.create.topics.enable: true
      temp.auto.create.topics.enable: false
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 20Gi
      deleteClaim: true
      class: gp2
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF
#           class: ${local.ingress_nginx_ingress_class}
}

# test sasl scram 
# nosemgrep: resource-not-on-allowlist
resource "kubectl_manifest" "kafka_test_sasl_secret" {
  count = 1
  depends_on      = [ kubectl_manifest.kafka_cluster ]
  yaml_body = <<-EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${local.sasl_scram_test_secret_name}
  namespace: ${kubernetes_namespace.kafka.id}
data:
  ${local.sasl_scram_test_secret_password_field}: ${local.base64_sasl_scram_test_secret_password}
  EOF
}

resource "time_sleep" "kafka_test_sasl_secret_wait" {
  depends_on      = [kubectl_manifest.kafka_test_sasl_secret]
  create_duration = "3s"
}

# nosemgrep: resource-not-on-allowlist
resource "kubectl_manifest" "kafka_test_sasl_secret_kafkauser" {
  count = 1
  depends_on = [time_sleep.kafka_test_sasl_secret_wait]
  yaml_body  = <<-EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: ${local.sasl_scram_test_secret.username}
  namespace: ${kubernetes_namespace.kafka.id}
  labels:
    strimzi.io/cluster: ${local.kafka_name}
spec:
  authentication:
    type: scram-sha-512
    password:
      valueFrom:
        secretKeyRef:
          name: ${local.sasl_scram_test_secret_name}
          key: ${local.sasl_scram_test_secret_password_field}
  EOF
}

# nosemgrep: resource-not-on-allowlist
resource "kubectl_manifest" "kafka_broker_internal_cert" {
  count = 1
  depends_on = [ kubernetes_namespace.kafka ]
  yaml_body = <<-EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${local.kafka_broker_internal_cert}
  namespace: ${local.kafka_namespace}
spec:
  secretName: ${local.kafka_broker_internal_cert}
  issuerRef:
    name: ${local.kafka_broker_internal_ca}
    kind: Issuer
  duration: 2160h
  renewBefore: 360h
  subject:
    organizationalUnits:
      - "kafka"
    organizations:
      - "Thought Machine Ltd"
  dnsNames:
    - "${local.kafka_subdomain}"
    - "*.${local.kafka_subdomain}"
    - "kafka.svc.cluster.local"
    - "*.kafka.svc.cluster.local"
EOF
}

resource "kubectl_manifest" "kafka_broker_internal_ca" {
  depends_on = [ kubernetes_namespace.kafka ]
  yaml_body = <<-EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ${local.kafka_broker_internal_ca}
  namespace: ${kubernetes_namespace.kafka.id}
spec:
  selfSigned: {}
EOF
}