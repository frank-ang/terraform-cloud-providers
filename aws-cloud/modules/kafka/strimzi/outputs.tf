output cluster_name {
    value = local.kafka_name
}

output "strimzi_kafka_ca_cert_path" {
  value = "${local.strimzi_kafka_ssl_dir_path}/ca.crt"
}

output "strimzi_kafka_tls_cert_path" {
  value = "${local.strimzi_kafka_ssl_dir_path}/tls.crt"
}

output "bootstrap_brokers_sasl_scram" {
  value = "${local.kafka_name}-kafka-bootstrap.${local.kafka_namespace}.svc.cluster.local:9097"
}
