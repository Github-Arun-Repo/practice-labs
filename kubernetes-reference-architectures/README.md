# Kubernetes Reference Architectures

Production-oriented Kubernetes architecture patterns designed for platform teams that want reusable, tested blueprints rather than one-off manifests.

---

## What Is Kubernetes?

Kubernetes is an open-source container orchestration platform that runs and manages containerized workloads at scale.

At a high level, Kubernetes provides:

- **Scheduling**: places containers (pods) onto suitable worker nodes
- **Desired state reconciliation**: continuously drives live state toward declared state
- **Service discovery and load balancing**: routes traffic to healthy pods
- **Self-healing**: replaces failed pods and restarts unhealthy workloads
- **Scalable operations**: supports horizontal scaling and rolling updates

### Basic Kubernetes Overview

Kubernetes has two major layers:

- **Control plane**: API server, scheduler, and controllers that decide and enforce desired state
- **Worker nodes**: run the actual application containers via kubelet and container runtime

Core objects you will see in this repository:

- **Namespace**: logical boundary for teams and environments
- **Deployment**: declarative workload management for stateless applications
- **Service**: stable network endpoint in front of pods
- **ResourceQuota / LimitRange**: resource governance per namespace
- **Role / RoleBinding / ServiceAccount**: identity and access control
- **NetworkPolicy**: traffic segmentation and isolation
- **Secret**: namespace-scoped sensitive configuration data

This section focuses on production architecture patterns, not Kubernetes installation basics.

---

## Why This Section Exists

This repository already teaches GitOps and CI/CD patterns. The Kubernetes section exists to complete the platform story:

- CI/CD builds immutable artifacts
- GitOps reconciles desired state
- Kubernetes architecture patterns define safe runtime boundaries for teams and workloads

We created this section to teach engineers how to design Kubernetes platforms that are secure, multi-tenant, and operationally predictable.

---

## Quick Start - Choose Your Path

**I want to understand why these patterns matter:**
-> [Read Kubernetes architecture principles](#kubernetes-architecture-principles)

**I want the implementation runbook now:**
-> [Open the Kubernetes runbook](./kubernetes-runbook.md)

**I want to verify pre-requisites and tooling first:**
-> [Open installation and prerequisites](./installation-kubernetes-prerequisites.md)

**I want to start with multi-cluster strategy patterns:**
-> [Start with Multi-Cluster Strategy (Pattern 1)](./multi-cluster-strategy/README.md)

---

## Kubernetes Architecture Principles

Before applying any pattern, align on foundational platform principles:

**Isolation by Default**
Workloads from different teams should be isolated by namespace, policy, and identity boundaries.

**Least Privilege Access**
Service accounts and users should get only the permissions they need in their own scope.

**Resource Governance**
Every tenant namespace should enforce quotas and default limits to prevent noisy-neighbor incidents.

**Network Segmentation**
Cross-namespace communication should be explicit and allow-listed, not open by default.

**Repeatable Operations**
Patterns must be reproducible via declarative manifests and runbooks, with failure tests included.

**Operational Verification**
Every pattern should include failure tests and recovery checks so teams can validate behavior under stress, not only in happy paths.

---

## Why Architecture Patterns Matter

Teams often succeed with Kubernetes in isolated proofs of concept but fail during shared-platform operations. Common causes:

- Namespace boundaries without RBAC or NetworkPolicy
- Quotas missing, enabling noisy-neighbor resource exhaustion
- Service accounts over-privileged by default
- No runbook to validate control behavior in failure conditions

The patterns in this section are designed to close that gap by combining design guidance, manifests, and timed operational runbooks.

---

## Pattern Catalog

| Pattern | What It Demonstrates | Documentation |
|---|---|---|
| **Pattern 1: Multi-Cluster Strategy (Shared Cluster Multi-Tenancy Baseline)** | Multiple teams safely sharing one Kubernetes cluster using namespace isolation, quotas, limits, RBAC, network policies, service accounts, and secret boundaries. | [Explore pattern](./multi-cluster-strategy/README.md) |

---

## Learning Path

1. Read this root guide to understand Kubernetes platform fundamentals.
2. Study the pattern README for architecture and design trade-offs.
3. Execute the timed runbook for implementation and validation.
4. Run all failure tests and document outcomes.
5. Adapt quotas, RBAC, and network policy controls for your organization.

---

## Implementation Runbooks

- [Kubernetes runbook index](./kubernetes-runbook.md)
- [Pattern 1 runbook: shared-cluster multi-tenancy](./multi-cluster-strategy/multi-cluster-runbook.md)

---

## Production Readiness Checklist

- Namespace-per-team model implemented
- ResourceQuota and LimitRange enforced per namespace
- Team-specific service accounts and RBAC bindings
- Default-deny network policy with explicit allow rules
- Secret scope limited to namespace boundaries
- Failure tests run and documented

---

## Next Patterns Planned

- True multi-cluster fleet strategy (cluster-per-environment and cluster-per-business-domain)
- Multi-cluster traffic management and failover
- Cluster policy enforcement with admission controls
- Workload identity and secret externalization patterns
