
# https://bank-vaults.dev/docs/installing/
terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

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
  vault_installer_role_name    = "vault-installer"
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

resource "kubernetes_namespace" "hault" {
  metadata {
    name = local.hault_namespace
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "helm_release" "hault_operator" {
  name       = local.hault_operator_chart_name
  repository = "oci://ghcr.io/bank-vaults/helm-charts"
  chart      = local.hault_operator_chart_name
  namespace  = kubernetes_namespace.hault.id
  version    = local.bank_vaults_operator_version
}

resource "kubectl_manifest" "hault_service_account" {
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
#  annotations:
#    eks.amazonaws.com/role-arn: \$\{module.hault_irsa_role.iam_role_arn}
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
- apiGroups:
  - authentication.k8s.io
  resources:
  - tokenreviews
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
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
  depends_on = [kubectl_manifest.hault_service_account]
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
  depends_on = [kubectl_manifest.hault_service_account]
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
  image: hashicorp/vault:1.14.1

  # Common annotations for all created resources
  annotations:
    common/annotation: "true"

  # Vault Pods , Services and TLS Secret annotations
  vaultAnnotations:
    type/instance: "vault"

  # Vault Configurer Pods and Services annotations
  vaultConfigurerAnnotations:
    type/instance: "vaultconfigurer"

  # Vault Pods , Services and TLS Secret labels
  vaultLabels:
    example.com/log-format: "json"

  # Vault Configurer Pods and Services labels
  vaultConfigurerLabels:
    example.com/log-format: "string"

  # Specify the Service's type where the Vault Service is exposed
  # Please note that some Ingress controllers like https://github.com/kubernetes/ingress-gce
  # forces you to expose your Service on a NodePort
  serviceType: ClusterIP

  # Request an Ingress controller with the default configuration
  #ingress:
    # Specify Ingress object annotations here, if TLS is enabled (which is by default)
    # the operator will add NGINX, Traefik and HAProxy Ingress compatible annotations
    # to support TLS backends
    #annotations: {}
    # Override the default Ingress specification here
    # This follows the same format as the standard Kubernetes Ingress
    # See: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#ingressspec-v1beta1-extensions
    #spec: {}

  # Use local disk to store Vault raft data, see config section.
  volumeClaimTemplates:
    - metadata:
        name: vault-raft
      spec:
        # https://kubernetes.io/docs/concepts/storage/persistent-volumes/#class-1
        # storageClassName: ""
        accessModes:
          - ReadWriteOnce
        volumeMode: Filesystem
        resources:
          requests:
            storage: 1Gi

  volumeMounts:
    - name: vault-raft
      mountPath: /vault/file

  # Add Velero fsfreeze sidecar container and supporting hook annotations to Vault Pods:
  # https://velero.io/docs/v1.2.0/hooks/
  veleroEnabled: true

  # Support for distributing the generated CA certificate Secret to other namespaces.
  # Define a list of namespaces or use ["*"] for all namespaces.
  caNamespaces:
    - "vswh"

  # Describe where you would like to store the Vault unseal keys and root token.
  unsealConfig:
    options:
      # The preFlightChecks flag enables unseal and root token storage tests
      # This is true by default
      preFlightChecks: true
      # The storeRootToken flag enables storing of root token in chosen storage
      # This is true by default
      storeRootToken: true
      # The secretShares represents the total number of unseal key shares
      # This is 5 by default
      secretShares: 5
      # The secretThreshold represents the minimum number of shares required to reconstruct the unseal key
      # This is 3 by default
      secretThreshold: 3
    kubernetes:
      secretNamespace: default
      
  # Specify the ServiceAccount where the Vault Pod and the Bank-Vaults configurer/unsealer is running
  serviceAccount: ${local.hault_name}

  serviceType: ClusterIP
  # cannot use the ingress cert so we need to use self signed
  # existingTlsSecretName: ${local.hault_name}-tls

  # A YAML representation of a final vault config file.
  # See https://www.vaultproject.io/docs/configuration/ for more information.
  config:
    storage:
      raft:
        path: "/vault/file"
    listener:
      tcp:
        address: "0.0.0.0:8200"
        tls_cert_file: /vault/tls/server.crt
        tls_key_file: /vault/tls/server.key
    api_addr: https://vault.default:8200
    cluster_addr: "https:/$${.Env.POD_NAME}:8201"
    ui: true

  statsdDisabled: true

  serviceRegistrationEnabled: true

  resources:
    # A YAML representation of resource ResourceRequirements for vault container
    # Detail can reference: https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container
    vault:
      limits:
        memory: "512Mi"
        cpu: "200m"
      requests:
        memory: "256Mi"
        cpu: "100m"

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
          path "secret/${var.secret_prefix}/*" {
            capabilities = ["create", "read", "update", "delete", "list"]
          }

          # Required by Observability packages installer
          path "secret/monitoring/*" {
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
          path "auth/secret/role/*"{
            capabilities = ["create", "read", "update", "delete"]
          }

    auth:
      - type: kubernetes
        path: secret
        description: kubernetes auth backend for EKS cluster
        roles:
          - name: ${local.vault_installer_role_name}
            bound_service_account_namespaces: ${var.vault_installer_namespace}
            bound_service_account_names: ${var.vault_installer_serviceaccount}
            policies: vault-installer-hashicorp-vault-policy
            ttl: 1h

    secrets:
      - path: secret
        type: kv
        description: General secrets.
        options:
          version: 2

      #- type: pki
      #  path: TODO
      #  description: Hault PKI secret engine to sign Kafka mTLS certificates

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
    cert-manager.io/cluster-issuer: ${var.cluster_issuer}
    external-dns.alpha.kubernetes.io/ingress-hostname-source: defined-hosts-only
    # required as hault uses TLS with a self signed cert
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
  namespace: ${kubernetes_namespace.hault.id}
spec:
  ingressClassName: ${var.ingress_class_name}
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
