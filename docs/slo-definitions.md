# SLO Definitions — BNY Payment Platform

## Service: Payment Gateway API

| SLI | Target | Measurement Window |
|---|---|---|
| Availability | 99.95% | 30-day rolling |
| Transaction latency p99 | < 500ms | 5-min rolling |
| Transaction latency p50 | < 100ms | 5-min rolling |
| Error rate (5xx) | < 0.1% | 1-hour rolling |

## Error Budget

- Monthly error budget: 0.05% × 43,200 min = **21.6 minutes/month**
- Budget burn rate alert threshold: > 5× (exhausts budget in 6 days)
- Fast burn alert: p99 latency > 1000ms for 2 consecutive minutes → PagerDuty P1
- Slow burn alert: error rate > 0.5% for 30 minutes → PagerDuty P2

## Prometheus Alert Rules

```yaml
groups:
- name: payment-api-slos
  rules:
  - alert: PaymentAPIHighErrorRate
    expr: |
      sum(rate(http_requests_total{app="payment-api",status=~"5.."}[5m]))
      /
      sum(rate(http_requests_total{app="payment-api"}[5m])) > 0.001
    for: 2m
    labels:
      severity: critical
      team: platform
    annotations:
      summary: "Payment API error rate above SLO threshold"
      runbook: "https://github.com/my-git-2024/terraform-aws-demo/blob/main/docs/runbook-eks.md"

  - alert: PaymentAPIHighLatency
    expr: |
      histogram_quantile(0.99,
        sum(rate(http_request_duration_seconds_bucket{app="payment-api"}[5m])) by (le)
      ) > 0.5
    for: 2m
    labels:
      severity: warning
      team: platform
    annotations:
      summary: "Payment API p99 latency above 500ms SLO"
```

## Blameless Postmortem Template

```
## Incident: [TITLE]
**Date:** YYYY-MM-DD
**Duration:** X hours Y minutes
**Severity:** P1 / P2
**Incident Commander:** [name]

### Timeline
- HH:MM — First alert fired (PagerDuty)
- HH:MM — On-call engineer acknowledged
- HH:MM — Root cause identified
- HH:MM — Mitigation applied
- HH:MM — Service restored

### Root Cause
[Technical description — no blame language]

### Contributing Factors
- [Factor 1]
- [Factor 2]

### Impact
- Users affected: X
- Transactions impacted: Y
- SLO burn: Z minutes of error budget

### Action Items
| Action | Owner | Due Date |
|---|---|---|
| [Preventive measure] | [team] | YYYY-MM-DD |

### What Went Well
- [Detection was fast]
- [Rollback worked correctly]
```
