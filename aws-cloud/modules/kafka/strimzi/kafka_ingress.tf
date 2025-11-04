# https://kubernetes.github.io/ingress-nginx/deploy/
locals {
  ingress_nginx_ingress_class = "nginx-kafka"
}

resource "helm_release" "kafka_nginx_ingress_controller" {
  # depends_on = [ null_resource.kubectl, module.aws_load_balancer_controller_irsa_role, helm_release.aws_load_balancer_controller ]
  name       = local.ingress_nginx_ingress_class # "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = local.kafka_namespace
  create_namespace = true
  version = "4.13.2"
  # https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml
  set = [
    {
      name  = "controller.service.type"
      value = "LoadBalancer"
    },
    {
      # https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/service/annotations/#traffic-routing
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "external"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
      value = "ip"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
      value = "internal"
    },
    {
      # To allow ingress controller to see clients source IPs in order to do IP whitelisting
      name  = "controller.service.externalTrafficPolicy"
      value = "Local"
    },
    {
      name = "controller.ingressClass"
      value = local.ingress_nginx_ingress_class
    },
    {
      name  = "controller.ingressClassResource.controllerValue"
      value = "k8s.io/${local.ingress_nginx_ingress_class}"
    },
    {
      name  = "controller.ingressClassResource.name"
      value = local.ingress_nginx_ingress_class
    },
    {
      # Process Ingress objects without ingressClass annotation/ingressClassName field Overrides value for --watch-ingress-without-class flag of the controller binary
      name  = "controller.watchIngressWithoutClass"
      value = "false"
    },
    {
      # We enable ssl passthrough for strimzi kafka
      name  = "controller.extraArgs.enable-ssl-passthrough"
      value = "true"
    },
  ]
}

resource "kubectl_manifest" "kafka_ingress" {
  count = 0 # Redundant. Ingress instances will be created by strimzi operator.
  depends_on = [
    helm_release.kafka_nginx_ingress_controller
  ]
  yaml_body = <<-EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: ${local.kafka_bootstrap_hostname}
    ingress.kubernetes.io/ssl-passthrough: "true"
    kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
    nginx.ingress.kubernetes.io/backend-protocol: ssl
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    tmachine.io/dns.class: private
  labels:
    app: strimzi-kafka
    project: kafka
  name: ${local.kafka_bootstrap_hostname}
  namespace: ${local.kafka_namespace}
spec:
  ingressClassName: ${local.ingress_nginx_ingress_class}
  tls:
    - hosts:
        - ${local.kafka_bootstrap_hostname}
        - "*.kafka.svc.cluster.local"
      secretName: ${local.kafka_broker_internal_cert}
  rules:
    - host: ${local.kafka_bootstrap_hostname}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${local.kafka_name}-kafka-external-bootstrap
                port:
                  number: ${local.kafka_external_port}
EOF
}