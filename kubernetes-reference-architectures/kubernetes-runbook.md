# Kubernetes Reference Architectures - Runbook Index

This runbook is the entry point for Kubernetes architecture implementation walkthroughs in this repository.

---

## Scope

Current implementations available:

- [Multi-Cluster Strategy: Shared Cluster Multi-Tenancy](./multi-cluster-strategy/multi-cluster-runbook.md)
- [Autoscaling Reference Patterns: HPA and VPA](./autoscaling-reference-patterns/autoscaling-runbook.md)
- [Zero-Downtime Deployment Strategies: Rolling Update, Blue/Green, Canary](./zero-downtime-deployment-strategies/zero-downtime-runbook.md)
- [Pod Health Probes: Startup, Liveness, Readiness](./pod-health-probes/probes-runbook.md)

---

## Recommended Runbook Flow

1. Validate prerequisites with [installation-kubernetes-prerequisites.md](./installation-kubernetes-prerequisites.md).
2. Review architecture and goals in the pattern README.
3. Execute the full runbook from top to bottom.
4. Run all failure tests and record outcomes.

---

## Timing Plan

- Pre-flight and cluster capability checks: 5-8 minutes
- Pattern architecture review: 8-10 minutes
- Implementation apply and baseline verification: 12-15 minutes
- Failure test execution and cleanup: 20-25 minutes
- **Total expected runbook duration:** 45-60 minutes

---

## Teaching Goal

The objective is to show platform engineers how Kubernetes guardrails work under normal and failure conditions, not just how to apply YAML.
