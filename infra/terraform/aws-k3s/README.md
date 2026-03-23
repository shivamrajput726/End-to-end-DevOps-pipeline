# Terraform: AWS EC2 + single-node k3s

This module provisions an EC2 instance and bootstraps a single-node Kubernetes cluster using **k3s**.

## Prerequisites

- AWS account + credentials configured (`aws configure`)
- Terraform >= 1.5
- An SSH key pair (public key content)

## Quick start

```bash
cd infra/terraform/aws-k3s
terraform init
terraform apply
```

After `apply`, Terraform prints:
- EC2 public IP
- An `ssh` command
- A `scp` command to fetch kubeconfig

## Notes

- This is a demo-ready cluster (single-node). For production, use a managed cluster (EKS) and multiple nodes.

