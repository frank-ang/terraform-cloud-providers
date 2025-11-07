
# https://bank-vaults.dev/docs/installing/
locals {
  hault_name                   = "hault"
  hault_namespace              = "hault-system"
  hault_hostname               = "${local.hault_name}.${var.project_domain}"
  hault_api_addr               = "https://${local.hault_hostname}:443"
  hault_port                   = 8200
  hault_operator_chart_name    = "vault-operator"
  hault_operator_namespace     = local.hault_namespace
  hault_s3_bucket_name         = "${var.project}-bank-vaults-tm"
  hault_dynamodb_table_name    = "${var.project}-bank-vaults"
  hault_kms_key_alias          = "${var.project}-${local.hault_name}"
  bank_vaults_operator_version = "1.22.0" #https://github.com/bank-vaults/vault-operator
  bank_vaults_image_version    = "1.31.0" #https://github.com/bank-vaults/bank-vaults
}

data "aws_iam_policy_document" "hault_irsa_policy" {
  statement {
    sid = "KMS"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt"
    ]
    resources = ["*"]
  }
  statement {
    sid = "S3"
    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]
    resources = ["*"]
  }

  statement {
    sid = "S3ListBucket"
    actions = [
      "s3:ListBucket",
    ]
    resources = ["*"]
  }

  statement {
    sid = "DynamoDB"
    actions = [
      "dynamodb:*",
    ]
    resources = [aws_dynamodb_table.hault.arn]
  }
}

resource "aws_iam_policy" "hault_irsa_policy" {
  name        = "${var.project}-${local.hault_name}"
  description = "Access S3 and KMS for hault"
  policy      = data.aws_iam_policy_document.hault_irsa_policy.json
}


module "hault_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.37.0"

  role_name = "${var.project}-${local.hault_name}"


  role_policy_arns = {
    _ = aws_iam_policy.hault_irsa_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = local.eks_oidc_provider_arn
      namespace_service_accounts = ["${kubernetes_namespace.hault.id}:${local.hault_name}"]
    }
  }
}

resource "aws_kms_key" "hault" {
  description         = "CMK used for encryption/decryption of hault unseal keys and root token"
  enable_key_rotation = true
}

resource "aws_kms_alias" "hault" {
  name          = "alias/${local.hault_kms_key_alias}"
  target_key_id = aws_kms_key.hault.key_id
}

module "hault_s3" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.0"


  bucket = local.hault_s3_bucket_name
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"
  force_destroy            = true

  versioning = {
    enabled = false
  }
}

resource "aws_dynamodb_table" "hault" {
  name           = local.hault_dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "Path"
  range_key      = "Key"

  attribute {
    name = "Path"
    type = "S"
  }

  attribute {
    name = "Key"
    type = "S"
  }
}

resource "kubernetes_namespace" "hault" {
  metadata {
    name = local.hault_namespace
  }
}

resource "helm_release" "hault_operator" {
  name       = local.hault_operator_chart_name
  repository = "oci://ghcr.io/bank-vaults/helm-charts"
  chart      = local.hault_operator_chart_name
  namespace  = kubernetes_namespace.hault.id
  version    = local.bank_vaults_operator_version
}

resource "kubectl_manifest" "hault_sa" {
  yaml_body = <<-EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: vault-operator
    app.kubernetes.io/instance: vault-sa
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: serviceaccount
    app.kubernetes.io/part-of: vault-operator
  annotations:
    eks.amazonaws.com/role-arn: ${module.hault_irsa_role.iam_role_arn}
  name: ${local.hault_name}
  namespace: ${kubernetes_namespace.hault.id}
 EOF
}

resource "kubectl_manifest" "hault_role" {
  yaml_body = <<-EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${local.hault_name}
  namespace: ${kubernetes_namespace.hault.id}
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - patch
  - update
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - '*'
 EOF
}

resource "kubectl_manifest" "hault_role_leader_election" {
  yaml_body = <<-EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: vault-operator
    app.kubernetes.io/instance: leader-election-role
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: role
    app.kubernetes.io/part-of: vault-operator
  name: ${local.hault_name}-leader-election-role
  namespace: ${kubernetes_namespace.hault.id}
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - patch
 EOF
}

resource "kubectl_manifest" "hault_rolebinding_leader_election" {
  yaml_body  = <<-EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: vault-operator
    app.kubernetes.io/instance: leader-election-rolebinding
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: rolebinding
    app.kubernetes.io/part-of: vault-operator
  name: ${local.hault_name}-leader-election-rolebinding
  namespace: ${kubernetes_namespace.hault.id} 
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${local.hault_name}-leader-election-role
subjects:
- kind: ServiceAccount
  name: ${local.hault_name}
 EOF
  depends_on = [kubectl_manifest.hault_sa]
}

resource "kubectl_manifest" "hault_rolebinding" {
  yaml_body  = <<-EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: vault-operator
    app.kubernetes.io/instance: manager-rolebinding
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: rolebinding
    app.kubernetes.io/part-of: vault-operator
  name: ${local.hault_name}
  namespace: ${kubernetes_namespace.hault.id} 
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${local.hault_name}
subjects:
- kind: ServiceAccount
  name: ${local.hault_name}
 EOF
  depends_on = [kubectl_manifest.hault_sa]
}

resource "kubectl_manifest" "hault_clusterrolebinding" {
  yaml_body = <<-EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/component: rbac
    app.kubernetes.io/created-by: vault-operator
    app.kubernetes.io/instance: manager-rolebinding
    app.kubernetes.io/managed-by: kustomize
    app.kubernetes.io/name: clusterrolebinding
    app.kubernetes.io/part-of: vault-operator
  name: ${local.hault_name}-auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: ${local.hault_name}
  namespace: ${kubernetes_namespace.hault.id} 
 EOF
}

resource "kubectl_manifest" "hault" {
  yaml_body = <<-EOF
apiVersion: "vault.banzaicloud.com/v1alpha1"
kind: Vault
metadata:
  name: ${local.hault_name}
  namespace: ${kubernetes_namespace.hault.id}
spec:
  size: 3
  image: hashicorp/vault:${var.hault_version}
  bankVaultsImage: ghcr.io/bank-vaults/bank-vaults:v${local.bank_vaults_image_version}
  statsdImage: prom/statsd-exporter:v0.9.0


  # Describe where you would like to store the Vault unseal keys and root token
  # in S3 encrypted with KMS.
  unsealConfig:
    aws:
      kmsKeyId: ${aws_kms_key.hault.key_id}
      kmsRegion: ${var.aws_region}
      s3Bucket: ${module.hault_s3.s3_bucket_id}
      s3Prefix: "${local.hault_operator_chart_name}/"
      s3Region: ${var.aws_region}

  # Specify the ServiceAccount where the Vault Pod and the Bank-Vaults configurer/unsealer is running
  serviceAccount: ${local.hault_name}

  serviceType: ClusterIP
  # cannot use the ingress cert so we need to use self signed
  # existingTlsSecretName: ${local.hault_name}-tls

  # A YAML representation of a final vault config file, this config represents
  # a backend config in AWS.
  # See https://www.vaultproject.io/docs/configuration/ for more information.
  config:
    storage:
      # s3: #only work if size=1
      #   region: ${var.aws_region}
      #   bucket: ${module.hault_s3.s3_bucket_id}
      dynamodb:
        ha_enabled: true
        region: ${var.aws_region}
        table: ${aws_dynamodb_table.hault.id}
    listener:
      tcp:
        address: "0.0.0.0:8200"
        tls_cert_file: /vault/tls/server.crt
        tls_key_file: /vault/tls/server.key
    api_addr: ${local.hault_api_addr}
    cluster_addr: https://$${.Env.POD_NAME}:8201
    telemetry:
      statsd_address: localhost:9125
    ui: true

  vaultEnvsConfig:
  - name: VAULT_LOG_LEVEL
    values: debug


  # See: https://banzaicloud.com/docs/bank-vaults/cli-tool/#example-external-vault-configuration
  # The repository also contains a lot examples in the test/deploy and operator/deploy directories.
  externalConfig:
    policies:
      - name: admin
        rules: |
          path "*" {
            capabilities = ["create", "read", "update", "delete", "list", "sudo"]
          }
      - name: vault-installer-hashicorp-vault-policy
        rules: |
          # Required for vault installer to manage internal secrets and certs used by Thought Machine Vault
          path "${var.hault_kv_secret_engine.name}/${var.secret_prefix}/*" {
            capabilities = ["create", "read", "update", "delete", "list"]
          }

          # Required by Observability packages installer
          path "${var.hault_kv_secret_engine.name}/monitoring/*" {
            capabilities = ["create", "read", "update", "delete", "list"]
          }

          # Required for the vault installer to determine whether it has a valid HashiCorp Vault access token
          path "auth/token/lookup-self" {
            capabilities = ["read"]
          }

          # Optional: allows vault installer to automatically create policies for services in HashiCorp Vault
          path "sys/policy/*" {
            capabilities = ["create", "read", "update", "delete"]
          }

          # Optional: allows vault installer to automatically create policies for services in HashiCorp Vault
          path "auth/${var.hault_kv_secret_engine.name}/role/*"{
            capabilities = ["create", "read", "update", "delete"]
          }

    auth:
      - type: kubernetes
        path: ${var.hault_kubernetes_auth_backend.name}
        description: kubernetes auth backend for ${local.eks_cluster_name} EKS cluster
        roles:
          - name: ${var.hault_kubernetes_auth_backend.vault_installer_role_name}
            bound_service_account_namespaces: ${var.vault_installer_namespace}
            bound_service_account_names: ${var.vault_installer_serviceaccount}
            policies: vault-installer-hashicorp-vault-policy
            ttl: 1h

    secrets:
      - type: kv
        path: ${var.hault_kv_secret_engine.name}
        description: Hault KV secret engine  
        options:
          version: ${var.hault_kv_secret_engine.version}

      - type: pki
        path: ${var.hault_pki_secret_engine.name}
        description: Hault PKI secret engine to sign Kafka mTLS certificates
        config:
          default_lease_ttl: 8760h
          max_lease_ttl: 87600h
        configuration:
          config:
          - name: urls
            issuing_certificates: https://${local.hault_hostname}:443/v1/pki/ca
            crl_distribution_points: https://${local.hault_hostname}:443/v1/pki/crl
          root/generate:
          - name: internal
            common_name: ${local.hault_name}.${kubernetes_namespace.hault.id}
            ttl: 87600h
          roles:
          - name: ${var.hault_pki_secret_engine.vault_installer_role_name}
            allow_any_name: true
            enforce_hostnames: true
            ttl: 8760h

    # Allows writing some secrets to Vault (useful for development purposes).
    # See https://www.vaultproject.io/docs/secrets/kv/index.html for more information.
    startupSecrets:
      - type: kv
        path: ${var.hault_kv_secret_engine.name}/data/${var.secret_prefix}/${local.root_db_secrets_name}
        data:
          data:
            ${local.database_hostname}: ${local.database_credentials_admin_user_password}
      - type: kv
        path: ${var.hault_kv_secret_engine.name}/data/${var.secret_prefix}/${local.dummy_saml_idp_secrets_name}
        data:
          data:
            ${keys(var.basic_auth_credentials)[0]}: ${var.basic_auth_credentials[keys(var.basic_auth_credentials)[0]]}
            ${keys(var.basic_auth_credentials)[1]}: ${var.basic_auth_credentials[keys(var.basic_auth_credentials)[1]]}

EOF
  depends_on = [
    helm_release.hault_operator,
    kubectl_manifest.hault_ingress
  ]
}

resource "kubectl_manifest" "hault_ingress" {
  yaml_body = <<-EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${local.hault_name}
  annotations:
    cert-manager.io/cluster-issuer: ${local.cert_manager_selfsigned_cluster_issuer}
    external-dns.alpha.kubernetes.io/ingress-hostname-source: defined-hosts-only
    # required as hault uses TLS with a self signed cert
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
  namespace: ${kubernetes_namespace.hault.id}
spec:
  ingressClassName: ${local.ingress_class_name}
  tls:
  - hosts:
    - ${local.hault_hostname}
    secretName: ${local.hault_name}-ingress-cert
  rules:
  - host: ${local.hault_hostname}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${local.hault_name}
            port:
              number: ${local.hault_port}
    EOF
  depends_on = [
  ]
}
