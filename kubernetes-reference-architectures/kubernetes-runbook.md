# Kubernetes Reference Architectures - Runbook Index

This runbook is the entry point for Kubernetes architecture implementation walkthroughs in this repository.

---

## Scope

Current implementation available:

- [Multi-Cluster Strategy: Shared Cluster Multi-Tenancy](./multi-cluster-strategy/multi-cluster-runbook.md)

---

## Recommended Runbook Flow

1. Validate prerequisites with [installation-kubernetes-prerequisites.md](./installation-kubernetes-prerequisites.md).
2. Review architecture and goals in [multi-cluster-strategy/README.md](./multi-cluster-strategy/README.md).
3. Execute the full runbook from [multi-cluster-runbook.md](./multi-cluster-strategy/multi-cluster-runbook.md).
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
