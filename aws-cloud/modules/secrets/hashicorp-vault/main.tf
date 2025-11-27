terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.5.0"
    }
  }
}

locals {
  hault_name                   = "hault"
  hault_namespace              = "hault-system"
  hault_hostname               = "${local.hault_name}.${var.project_domain}"
  hault_api_addr               = "https://${local.hault_hostname}:443"
  hault_token                  = "root" # default for dev mode hault TODO remove and use VAULT_TOKEN env var.
  ingress_nginx_ingress_class  = var.ingress_class_name
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

provider "vault" {
  address = local.hault_api_addr
  token = local.hault_token
  skip_tls_verify = true
}

# https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide
# https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm
resource "helm_release" "hault_chart" {
  name       = "hault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = local.hault_namespace
  version    = "0.31.0"
  create_namespace = true
  values = [<<EOT
server:
  dev: # Run Vault in "dev" mode. This requires no further setup, no state management, no initialization, without needing to unseal, store keys, et. al. All data is lost on restart.
    enabled: true
  ingress:
    enabled: true
    annotations:
        kubernetes.io/ingress.class: ${local.ingress_nginx_ingress_class}
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
        external-dns.alpha.kubernetes.io/hostname: ${local.hault_hostname}
        # tmachine.io/dns.class: private
    ingressClassName: ${local.ingress_nginx_ingress_class}
    hosts:
      - host: ${local.hault_hostname}
        paths: []
EOT 
  ]
}

resource "vault_generic_secret" "root-db-secrets" {
  depends_on = [
    # data.kubernetes_ingress_v1.vault_ingress,
    helm_release.hault_chart
  ]
  path = "secret/${var.secret_prefix}/root-db-secrets"
  data_json = jsonencode(
    {
        "${var.database_hostname}" = var.database_password
    }
  )
}

resource "vault_generic_secret" "dummy-saml-idp-secrets" {
  depends_on = [
    # data.kubernetes_ingress_v1.vault_ingress,
    helm_release.hault_chart
  ]
  path = "secret/${var.secret_prefix}/dummy-saml-idp-secrets"
  data_json = jsonencode(
    {
        basic_auth_user     = var.dummy_saml_idp_basic_auth_user
        basic_auth_password = var.dummy_saml_idp_basic_auth_password
    }
  )
}
