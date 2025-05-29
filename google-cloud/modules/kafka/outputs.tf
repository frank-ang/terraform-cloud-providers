output "kafka_namespace" {
  description = "Namespace where Kafka is deployed"
  value       = var.kafka_namespace
}

output "kafka_cluster_name" {
  description = "Name of the Kafka cluster"
  value       = var.kafka_cluster_name
}

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers endpoint"
  value       = var.create_kafka_cluster ? "${var.kafka_cluster_name}-kafka-bootstrap:9092" : null
}

output "kafka_bootstrap_servers_tls" {
  description = "Kafka bootstrap servers TLS endpoint"
  value       = var.create_kafka_cluster ? "${var.kafka_cluster_name}-kafka-bootstrap:9093" : null
}

output "strimzi_operator_version" {
  description = "Version of the installed Strimzi operator"
  value       = var.strimzi_version
}

output "kafka_topics" {
  description = "List of created Kafka topics"
  value       = keys(var.kafka_topics)
}

output "kafka_users" {
  description = "List of created Kafka users"
  value       = keys(var.kafka_users)
}

output "kafka_connect_enabled" {
  description = "Whether Kafka Connect is enabled"
  value       = var.create_kafka_connect
}