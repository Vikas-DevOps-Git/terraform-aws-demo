# terraform-aws-demo — BNY Platform Engineering Reference

Production-grade AWS infrastructure for financial microservices.
Modular Terraform library + GitHub Actions CI/CD + Helm chart library.

## Architecture

- **VPC** — public/private subnets, NAT Gateway, Transit Gateway peering
- **EKS** — mixed spot/on-demand node groups, OIDC pod identity, KMS encryption
- **IAM** — least-privilege roles, OIDC-based pod identity
- **ALB** — HTTPS only, WAF association, access logging, deletion protection on prod
- **Vault** — dynamic secrets, Kubernetes auth, automated lease rotation

## Repository Structure

```
├── modules/          # Reusable Terraform modules
├── environments/     # Per-environment root configs (dev/staging/prod)
├── helm/             # Helm chart library + consumer charts
├── kubernetes/       # Raw K8s manifests (HPA, VPA, NetworkPolicy, PDB)
├── .github/workflows # GitHub Actions CI/CD pipelines
├── scripts/          # Python automation (health-check, vault rotation, triage)
└── docs/             # Architecture, SLO definitions, runbooks
```

## Prerequisites

```bash
terraform >= 1.6.0
helm >= 3.14
kubectl >= 1.29
python >= 3.9
pip install kubernetes hvac
```

## Local Validation (no AWS account needed)

```bash
# Validate all modules
for env in dev staging prod; do
  cd environments/$env
  terraform init -backend=false
  terraform validate
  cd ../..
done

# Lint Helm charts
helm dependency build helm/payment-api/
helm lint helm/payment-api/
helm lint helm/payment-api/ -f helm/payment-api/values-dev.yaml

# Run Python scripts (dry-run)
python scripts/eks_health_check.py --help
python scripts/vault_rotation.py --dry-run --vault-addr http://localhost:8200
python scripts/incident_triage.py --dry-run \
  --payload '{"id":"INC-001","title":"OOM kill on payment-api","environment":"production"}'
```

## CI/CD Pipeline

| Trigger | Workflow | Stages |
|---|---|---|
| Pull Request | `terraform-plan.yml` | tfsec → checkov → fmt → validate → plan → PR comment |
| Merge to main | `terraform-apply.yml` | dev → staging → prod (sequential with environment gates) |
| PR on helm/ | `helm-lint.yml` | lint → template render → dev/prod diff |
| Push any | `trivy-scan.yml` | IaC config scan → K8s manifest scan |

## SLO Targets

| Service | Availability | p99 Latency |
|---|---|---|
| Payment Gateway API | 99.95% | < 500ms |
| Transaction API | 99.9% | < 200ms |

See [docs/slo-definitions.md](docs/slo-definitions.md) for full definitions and alert rules.

## Security Posture

- All S3 state buckets encrypted with KMS
- EKS API endpoint private-only
- No long-lived AWS credentials — OIDC pod identity throughout
- Vault dynamic secrets with automated rotation across 50+ services
- Network policies: default-deny-all with explicit allow rules
- WAF on all ALBs — OWASP Top 10 protection
- SOX-compliant resource tagging on every resource

## Notes
Platform validated against EKS 1.30 — April 2025.
