# Architecture — BNY Platform Engineering

## Overview

Multi-environment AWS infrastructure for BNY Mellon financial microservices.
Supports 100+ microservices at 99.95% availability across dev/staging/prod.

```
                          ┌─────────────────────────────────────┐
                          │           GitHub Actions             │
                          │  PR: tfsec→checkov→plan→comment      │
                          │  Merge: dev→staging→prod apply       │
                          └──────────────┬──────────────────────┘
                                         │ terraform apply
                    ┌────────────────────▼──────────────────────┐
                    │                   AWS                      │
                    │  ┌──────────────────────────────────────┐  │
                    │  │              VPC (10.x.0.0/16)       │  │
                    │  │  Public Subnets       Private Subnets │  │
                    │  │  [ALB + WAF]          [EKS Nodes]     │  │
                    │  │  [NAT Gateway]        [RDS/MongoDB]   │  │
                    │  └──────────────────────────────────────┘  │
                    │  ┌──────────────────────────────────────┐  │
                    │  │              EKS Cluster              │  │
                    │  │  On-Demand NG    Spot NG              │  │
                    │  │  [core apps]     [burst workloads]    │  │
                    │  │  HPA (CPU/Mem)   VPA (recommendations)│  │
                    │  └──────────────────────────────────────┘  │
                    └────────────────────────────────────────────┘
```

## Module Dependencies

```
environments/dev
    ├── module: vpc       → outputs: vpc_id, subnet_ids
    ├── module: iam       → outputs: cluster_role_arn, node_role_arn
    ├── module: eks       → inputs: vpc outputs + iam outputs
    │                     → outputs: cluster_endpoint, oidc_provider_arn
    └── module: alb       → inputs: vpc outputs
```

## Security Decisions

| Decision | Rationale |
|---|---|
| Private EKS endpoint only | No public Kubernetes API exposure |
| Secrets encrypted via KMS | SOX compliance requirement |
| SOX-compliant tags on all resources | Mandatory audit trail for financial regulators |
| WAF on ALB | OWASP Top 10 protection for financial APIs |
| Vault dynamic secrets | Zero hardcoded credentials, automatic rotation |
| OIDC pod identity | No long-lived AWS credentials on nodes |
| Network policies deny-all | Micro-segmentation per FINRA guidance |
| Deletion protection on prod ALB | Prevent accidental outage on $49T AUC platform |
