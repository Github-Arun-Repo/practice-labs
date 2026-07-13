# Multi-Cluster Strategy - Pattern 1

## Shared Cluster Multi-Tenancy Baseline

This first strategy starts from a practical assumption: Kubernetes is already installed, and multiple teams need to share one cluster safely.

Although this is under "multi-cluster strategy", this baseline pattern is intentionally single-cluster. It establishes the tenant guardrails that must exist before scaling into true multi-cluster fleet patterns.

---

## What Is This Pattern?

This pattern demonstrates how to operate a shared Kubernetes cluster for multiple teams without allowing cross-team interference.

It combines seven controls into one baseline architecture:

- Namespace isolation
- Resource quotas
- Default CPU and memory policies
- RBAC boundaries
- Network segmentation
- Team-scoped service accounts
- Secrets separation

The objective is not only deployment, but verifiable policy enforcement under failure tests.

---

## Quick Start - Choose Your Path

**I want architecture context first:**
-> [Read pattern fundamentals](#pattern-fundamentals)

**I want to execute this implementation now:**
-> [Run the implementation runbook](./multi-cluster-runbook.md)

**I want manifest-level details:**
-> [Review folder layout](#folder-layout)

---

## What This Pattern Teaches

How multiple teams or applications can safely share one Kubernetes cluster using:

- Namespace isolation
- Resource quotas
- Default CPU and memory limits
- RBAC per team
- Network isolation
- Service accounts
- Secrets separation

---

## Architecture

```text
Shared Kubernetes cluster
        |
        |-- Team A namespace
        |    |-- ResourceQuota
        |    |-- LimitRange
        |    |-- RBAC
        |    `-- NetworkPolicy
        |
        `-- Team B namespace
             |-- ResourceQuota
             |-- LimitRange
             |-- RBAC
             `-- NetworkPolicy
```

---

## Pattern Fundamentals

### Why Shared-Cluster Multi-Tenancy Is Hard

A namespace alone does not provide full tenant isolation. Without additional controls:

- teams can consume disproportionate cluster resources
- workloads can communicate across namespaces unexpectedly
- service accounts may have permissions outside team boundaries
- secrets may be exposed through overbroad privileges

### How This Pattern Enforces Isolation

| Control | Purpose | Failure It Prevents |
|---|---|---|
| Namespace | Logical tenancy boundary | Resource sprawl across teams |
| ResourceQuota | Caps per-tenant resource usage | Noisy-neighbor cluster exhaustion |
| LimitRange | Injects and bounds container resource defaults | Unbounded pods and scheduling instability |
| RBAC + ServiceAccount | Team-scoped authorization | Cross-team administrative access |
| NetworkPolicy | Explicit traffic allow rules | Lateral movement across namespaces |
| Secret scope | Namespace-local sensitive data | Cross-tenant secret reads |

---

## Folder Layout

```text
multi-cluster-strategy/
├── README.md
├── multi-cluster-runbook.md
└── k8s/
    └── shared-cluster/
        ├── kustomization.yaml
        ├── team-a/
        │   ├── kustomization.yaml
        │   ├── namespace.yaml
        │   ├── resourcequota.yaml
        │   ├── limitrange.yaml
        │   ├── serviceaccount.yaml
        │   ├── rbac.yaml
        │   ├── networkpolicy.yaml
        │   ├── secret.yaml
        │   ├── deployment.yaml
        │   └── service.yaml
        └── team-b/
            ├── kustomization.yaml
            ├── namespace.yaml
            ├── resourcequota.yaml
            ├── limitrange.yaml
            ├── serviceaccount.yaml
            ├── rbac.yaml
            ├── networkpolicy.yaml
            ├── secret.yaml
            ├── deployment.yaml
            └── service.yaml
```

---

## Implementation Notes

- Team A and Team B are symmetric to make comparison and verification straightforward.
- Both teams use default-deny ingress/egress and explicit DNS egress allow rules.
- Limits are intentionally conservative for safe shared-cluster baseline behavior.
- All checks are codified in the runbook with expected outcomes.

---

## When To Use

- Platform teams operating a shared Kubernetes cluster
- Early-stage multi-tenant platform onboarding
- Internal environments where teams share control-plane and worker nodes
- Learning and validating namespace-level guardrails before multi-cluster expansion

## When Not To Use

- Strict regulatory boundaries requiring hard physical or account separation
- Tenant workloads that require dedicated cluster-level controls
- High-risk workloads with conflicting runtime dependencies and security profiles

---

## Operational Outcomes

By applying this pattern:

- Team A cannot manage Team B resources
- One namespace cannot consume all cluster CPU or memory
- Default limits are enforced for pods that omit resources
- Cross-namespace traffic is blocked by default
- Secrets remain namespace-scoped

---

## Failure Validation Matrix

This pattern includes explicit validation of the following failure questions:

- Can Team A access Team B resources?
- Can one namespace consume the entire cluster?
- Can an unauthorized user delete another team's deployment?
- Can one application connect to another namespace unexpectedly?

These are executed in the runbook as mandatory checks.

---

## Production Adaptation Guidance

- Adjust quota and limit values to match workload classes (batch, API, stateful).
- Enforce policy as code using GitOps workflows and pull-request approvals.
- Add admission controls (OPA/Gatekeeper or Kyverno) for stronger guardrails.
- Add external secret management for production credential lifecycle.

---

## Run It

Follow the complete step-by-step execution and failure tests here:

- [multi-cluster-runbook.md](./multi-cluster-runbook.md)
