# AWS Cloud Platform for Thought Machine Vault Core ![Tested](https://img.shields.io/badge/VaultCore5.7-in_progress-yellow)

Terraform templates to provision AWS Cloud infrastructure prerequisites necessary for deployment of the Thought Machine Vault Core banking platform. A prescriptive infrastructure is 

## Architecture Overview

Environments are configured in the [environments](./environments) directory. Currently, a nonprod environment is provided.

Each environment depends on a selection of supporting component Terraform modules in the [modules](./modules) directory.

The project structure is based on guidelines in [Terraform Best Practices for Large-size infrastructure with Terraform](https://www.terraform-best-practices.com/examples/terraform/large-size-infrastructure-with-terraform)

## Project Structure

```
aws-cloud/
├── modules/                    # Reusable Terraform modules
│   ├──db/                      # Modules for databases
│   ├──k8s/                     # Modules for Kubernetes clusters
│   ├──kafka/                   # Modules for Kafka clusters
│   ├──network/                 # Module for networking
│   ├──secrets/                 # Modules for secrets management
├── environments/               # Environment-specific configurations
│   ├── nonprod/                # Non-production environment
└── README.md                   # This file
```

## Features

### Database
* Amazon Aurora Serverless for PostgreSQL instance.

### Kubernetes Cluster
* Amazon EKS cluster. EKS managed node group. Add-ons for: cert-manager, ingress-nginx, AWS LB controller, EBS CSI, VPC CNI, Metrics Server, external-dns

### Kafka Cluster
* Amazon MSK cluster with 3 brokers.

### Network
* VPC network. Subnets across 3 Availability Zones, and DNS Route53 private zone.

### Secrets
* AWS Secrets Manager, creates a database root secret, and installs secrets-store CSI driver helm chart.

## Quick Start

### Prerequisites

* Workstation
  * Tested on: Linux host, Bash shell
  * aws cli v2
  * kubectl
  * terraform >= 1.0
* AWS Account
  * IAM principal with sufficient permissions

### Configure

Configure `terraform.tfvars` in the selected [environments](./environments)/ENV_NAME subdirectory.

### Create Environment

```sh
terraform init
terraform plan
terraform apply
```

### Install Thought Machine Vault Core

Please refer to Thought Machine Vault Core documentation.

### Destroy Environment (optional)

To deprovision a temporary environment.

```sh
terraform destroy
```
