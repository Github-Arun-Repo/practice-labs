# Platform Engineering Reference Architectures

A growing collection of practical infrastructure patterns, reference implementations, and production-oriented platform engineering examples.

## About This Repository

I am **Arunasalam Govindasamy**, an AWS Cloud Architect with extensive experience designing and building cloud infrastructure, Kubernetes platforms, Infrastructure as Code, GitOps, CI/CD, networking, and distributed systems.

I created this repository to share infrastructure patterns that engineers and architects can inspect, deploy, test, and learn from.

The implementations are not documentation-only examples. They have been built and validated through hands-on deployments, operational testing, failure scenarios, recovery exercises, and architecture analysis.

The goal is to explain not only **how infrastructure is created**, but also:

- Why a particular architecture was selected
- How the components work together
- How failures, drift, rollback, security, and scalability are handled
- What must be considered before using a pattern in production

## Reference Architectures

| Area | What It Covers | Documentation |
|---|---|---|
| **GitOps and Argo CD** | Argo CD Applications, App of Apps, ApplicationSets, automated sync, self-healing, drift detection, rollback, and recovery scenarios. | [Explore Argo CD architectures](./argocd-reference-architectures/README.md) |
| **Terraform Infrastructure** | Modular Terraform, multi-AZ AWS networking, secure S3 patterns, remote state, state locking, reusable modules, and architecture decisions. | [Explore Terraform patterns](./terraform/README.md) |

## Who This Is For

This repository is intended for:

- Cloud and platform architects
- DevOps and infrastructure engineers
- Kubernetes and GitOps engineers
- Engineers moving towards production-level infrastructure design

## Topics Being Added

The repository will continue to expand with:

- Kubernetes and Amazon EKS architecture
- CI/CD and deployment strategies
- Observability and monitoring
- Infrastructure security
- Kafka and event-driven systems
- Platform automation
- AI infrastructure on Kubernetes
- GPU workload scheduling, model hosting, and MLOps

## About Me

I specialise in AWS cloud architecture, Kubernetes, Amazon EKS, Terraform, GitOps, CI/CD, cloud networking, scalable infrastructure, and distributed systems.

I am currently extending my platform architecture expertise into AI infrastructure, including GPU-enabled Kubernetes platforms, AI workload hosting, autoscaling, observability, and MLOps.

> These implementations are provided as reference architectures. Review security, cost, availability, compliance, and organisational requirements before adapting them for production.
