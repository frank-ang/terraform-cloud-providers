# Google Cloud Kubernetes Platform

A comprehensive, production-ready Terraform configuration for deploying and managing multiple Kubernetes clusters on Google Cloud Platform with integrated Kafka and HashiCorp Vault using Bank Vaults.

## Architecture Overview

This platform provides:

- **Shared VPC Architecture**: Separate shared VPCs for non-production and production environments
- **Multi-Cluster Support**: Scalable GKE cluster deployment with configurable node pools
- **Namespace Management**: Automated namespace provisioning with RBAC, quotas, and network policies
- **Kafka Integration**: Strimzi-based Kafka deployment with high availability
- **Vault Integration**: HashiCorp Vault with Bank Vaults operator and GCP KMS auto-unseal
- **Database Integration**: CloudSQL PostgreSQL and AlloyDB with Auth Proxy for secure access
- **Security**: Network policies, Pod Security Policies, Binary Authorization, and Workload Identity
- **Monitoring**: Comprehensive logging and monitoring with Managed Prometheus

## Project Structure

```
google-cloud/
├── modules/                    # Reusable Terraform modules
│   ├── shared-vpc/            # Shared VPC with subnets and NAT
│   ├── gke-cluster/           # GKE cluster with best practices
│   ├── namespace/             # K8s namespace with policies
│   ├── kafka/                 # Strimzi Kafka deployment
│   ├── vault/                 # Bank Vaults deployment
│   ├── cloudsql/              # CloudSQL PostgreSQL with Auth Proxy
│   └── alloydb/               # AlloyDB with Auth Proxy
├── environments/              # Environment-specific configurations
│   ├── nonprod/              # Non-production environment
│   └── prod/                 # Production environment
├── k8s-apis.yaml             # Kubernetes API configuration reference
└── README.md                 # This file
```

## Features

### Kubernetes Cluster Features

- **Private GKE clusters** with configurable private endpoints
- **Node Auto Provisioning** with resource limits
- **Workload Identity** for secure GCP service integration
- **Binary Authorization** for container image security (production)
- **Network Policies** for micro-segmentation
- **Blue/Green node pool upgrades** for zero-downtime updates
- **Anti-affinity rules** for high availability (production)

### Kafka Features

- **Strimzi Operator** for Kafka lifecycle management
- **High Availability** configuration with multiple brokers and Zookeeper
- **Persistent Storage** with configurable storage classes
- **Topic and User Management** via Custom Resources
- **Kafka Connect** support for data integration
- **TLS encryption** for secure communication

### Vault Features

- **Bank Vaults Operator** for Vault lifecycle management
- **GCP KMS Auto-unseal** for enhanced security
- **High Availability** with Raft storage backend
- **Workload Identity** integration
- **Secret injection** via webhook
- **External configuration** support for policies and auth methods

### Database Features

#### CloudSQL PostgreSQL
- **Private IP** connectivity with VPC integration
- **Auth Proxy** for secure connections from Kubernetes
- **Automated backups** with point-in-time recovery
- **High availability** with regional configuration
- **Query insights** and performance monitoring
- **IAM integration** with Workload Identity

#### AlloyDB
- **High-performance** PostgreSQL-compatible database
- **Read replicas** for scale-out workloads
- **Intelligent auto-scaling** with read pools
- **Advanced security** with encryption at rest
- **Continuous backups** for data protection
- **Built-in analytics** capabilities

## Quick Start

### Prerequisites

1. **Google Cloud Projects**:
   - Host project (for shared VPC)
   - Service projects (for GKE clusters)

2. **GCP APIs** (enabled via Terraform):
   - Container API
   - Compute API
   - Secret Manager API
   - KMS API
   - Service Networking API

3. **Terraform** >= 1.0
4. **gcloud CLI** configured with appropriate permissions

### Deployment Steps

#### 1. Configure Backend

Create a GCS bucket for Terraform state:

```bash
gsutil mb gs://your-terraform-state-bucket
```

#### 2. Non-Production Deployment

```bash
cd environments/nonprod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project IDs and configuration
terraform init
terraform plan
terraform apply
```

#### 3. Production Deployment

```bash
cd environments/prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project IDs and configuration
terraform init
terraform plan
terraform apply
```

## Configuration

### Shared VPC Configuration

The shared VPC module creates:
- VPC network with custom subnets
- Cloud NAT for outbound internet access
- Service networking for managed services
- Firewall rules for secure communication

### GKE Cluster Configuration

Key configurations:
- **Node Pools**: Separate system and workload pools
- **Autoscaling**: Horizontal Pod Autoscaler and Cluster Autoscaler
- **Security**: Shielded nodes, secure boot, integrity monitoring
- **Networking**: Private nodes with authorized networks

### Namespace Configuration

Each namespace includes:
- **Resource Quotas**: CPU, memory, and object limits
- **Limit Ranges**: Default and maximum resource constraints
- **Network Policies**: Ingress/egress rules for isolation
- **RBAC**: Service accounts with minimal permissions
- **Pod Security Policies**: Runtime security constraints (production)

### Kafka Configuration

Kafka deployment includes:
- **Operator**: Strimzi for lifecycle management
- **Cluster**: Multi-broker setup with Zookeeper
- **Topics**: Declarative topic management
- **Users**: RBAC with ACLs
- **Storage**: Persistent volumes with configurable classes

### Vault Configuration

Vault deployment includes:
- **Operator**: Bank Vaults for advanced features
- **Auto-unseal**: GCP KMS integration
- **Storage**: Raft backend for HA
- **TLS**: Automatic certificate management
- **Policies**: External configuration support

### Database Configuration

#### CloudSQL Configuration
- **Private networking**: VPC-native with private IP
- **Auth Proxy**: Kubernetes deployment for secure access
- **Credentials management**: Auto-generated passwords in Kubernetes secrets
- **Backup strategy**: Automated daily backups with retention policies
- **Connection pooling**: Built-in connection management

#### AlloyDB Configuration
- **Cluster architecture**: Primary instance with optional read replicas
- **Auth Proxy**: Kubernetes deployment for secure connections
- **Workload Identity**: IAM-based authentication from GKE
- **Continuous backup**: Point-in-time recovery capabilities
- **Performance optimization**: Intelligent query acceleration

## Kubernetes API Configuration

The platform configures the following Kubernetes APIs and admission controllers:

### Core APIs
- `networking.k8s.io/v1` - Network Policies
- `policy/v1beta1` - Pod Security Policies
- `rbac.authorization.k8s.io/v1` - RBAC

### Admission Controllers
- `PodSecurityPolicy` - Runtime security policies
- `NetworkPolicy` - Network micro-segmentation
- `ResourceQuota` - Resource limits enforcement
- `LimitRanger` - Default resource constraints

### Custom Resource Definitions
- `kafka.strimzi.io/v1beta2` - Kafka resources
- `vault.banzaicloud.com/v1alpha1` - Vault resources

## Security Best Practices

### Network Security
- Private GKE clusters with authorized networks
- Network policies for namespace isolation
- VPC native networking with secondary ranges
- Cloud NAT for controlled outbound access

### Identity and Access
- Workload Identity for GCP service integration
- Service accounts with minimal permissions
- RBAC with least privilege principles
- Pod Security Policies for runtime constraints

### Data Protection
- Encryption at rest for persistent volumes
- TLS encryption for service communication
- Secrets management via Vault
- KMS integration for key management

### Compliance
- Binary Authorization for image validation (production)
- Audit logging for compliance requirements
- Resource usage monitoring and alerting
- Security scanning and vulnerability management

## Monitoring and Logging

### Built-in Monitoring
- **GKE Monitoring**: System and workload metrics
- **Managed Prometheus**: Custom metrics collection
- **Cloud Logging**: Centralized log aggregation
- **Audit Logs**: API server and data access logs

### Application Monitoring
- Service mesh integration ready
- Custom metrics via Prometheus
- Distributed tracing support
- Alert management and routing

## Maintenance and Updates

### Cluster Updates
- **Blue/Green node pool upgrades** for zero downtime
- **Maintenance windows** for system updates
- **Version pinning** for stability
- **Rollback procedures** for quick recovery

### Application Updates
- **Rolling updates** for stateless applications
- **Canary deployments** for risk mitigation
- **GitOps workflows** for automated deployments
- **Backup and restore** procedures

## Environment Differences

### Non-Production (`environments/nonprod/`)
- **Cluster Configuration**: REGULAR release channel, smaller node pools
- **Security**: Relaxed policies for development and testing
- **Kafka**: Single replica for cost optimization
- **Vault**: Single instance, debug logging enabled
- **Databases**: ZONAL availability, basic backup configuration
- **Monitoring**: Basic monitoring configuration

### Production (`environments/prod/`)
- **Cluster Configuration**: STABLE release channel, larger node pools
- **Security**: Pod Security Policies, Binary Authorization enabled
- **Kafka**: High availability with 3 replicas and anti-affinity
- **Vault**: High availability with 3 replicas and anti-affinity
- **Databases**: REGIONAL availability, full backup and monitoring
- **Monitoring**: Full monitoring with alerting

## Migration from Legacy Configuration

If migrating from the previous single-file configuration:

1. **Backup existing state**: `terraform state pull > backup.tfstate`
2. **Review configuration**: Compare old `terraform.tfvars` with new examples
3. **Import resources**: Use `terraform import` for existing resources if needed
4. **Deploy incrementally**: Start with non-production environment

## Module Usage

### Using Individual Modules

```hcl
module "gke_cluster" {
  source = "./modules/gke-cluster"
  
  project_id           = "my-project"
  cluster_name         = "my-cluster"
  location            = "europe-west2"
  network_self_link   = module.shared_vpc.network_self_link
  subnetwork_self_link = module.shared_vpc.subnets["primary"].self_link
  
  # Additional configuration...
}
```

### Customizing Node Pools

```hcl
node_pools = {
  compute = {
    initial_node_count = 0
    autoscaling = {
      min_node_count = 1
      max_node_count = 10
    }
    node_config = {
      machine_type = "c2-standard-4"
      spot        = false
      # Additional configuration...
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **VPC Peering**: Ensure non-overlapping CIDR ranges
2. **IAM Permissions**: Verify service account roles
3. **Quota Limits**: Check GCP quotas for resources
4. **Network Connectivity**: Validate firewall rules

### Useful Commands

```bash
# Get cluster credentials
gcloud container clusters get-credentials CLUSTER_NAME --location=LOCATION

# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Verify Kafka deployment
kubectl get kafka -n kafka

# Check Vault status
kubectl get vault -n vault

# Check database connections
kubectl get secret -l app.kubernetes.io/name=cloudsql-credentials
kubectl get secret -l app.kubernetes.io/name=alloydb-credentials

# Test database connectivity
kubectl run db-test --image=postgres:15 --rm -it --restart=Never -- psql "host=cloudsql-proxy.default.svc.cluster.local port=5432 dbname=app user=app"

# View API resources
kubectl api-resources

# Check network policies
kubectl get networkpolicy --all-namespaces
```

### Debugging Steps

1. **Check Terraform state**: `terraform state list`
2. **Validate configuration**: `terraform validate`
3. **Review logs**: Check GKE cluster logs in Cloud Console
4. **Network troubleshooting**: Use `kubectl exec` for connectivity tests

## Contributing

1. Follow Terraform best practices
2. Update documentation for new features
3. Test changes in non-production first
4. Use conventional commit messages
5. Ensure modules are reusable and well-documented

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review GCP documentation
3. Consult Kubernetes documentation
4. Check module-specific documentation
5. Open an issue with detailed information

## License

This project is licensed under the terms specified in the LICENSE file.