# Platform Engineering Reference Architectures

> A growing collection of validated infrastructure patterns, reference implementations, operational guidance, and reusable platform-engineering blueprints — covering Kubernetes, GitOps, AWS, Terraform, and AI infrastructure.

---

## About This Repository

This repository exists to share architecture knowledge in a form that engineers and architects can directly inspect, deploy, and build upon. It is not a set of theoretical diagrams — the implementations here are based on production experience and have been validated through hands-on environments, architecture exercises, deployment testing, and operational scenarios.

The repository covers both cloud-hosted and standalone infrastructure platforms. Each section explains not only what to deploy, but why particular design decisions are made, how components fit together, and what to do when things go wrong.

**What you will find here:**

- Reference architectures with documented design decisions
- Reusable infrastructure blueprints across cloud and Kubernetes
- GitOps and CI/CD implementation patterns
- Deployment, failure, recovery, and rollback scenarios
- Operational guidance informed by real enterprise infrastructure experience
- Production-readiness considerations, not just deployment instructions

The repository is continuously expanding. New sections covering advanced Kubernetes, multi-cluster GitOps, AWS platform patterns, observability, security, event-driven architecture, and AI infrastructure are planned and will be added progressively.

**Target audiences:**

- Cloud architects and platform engineers
- Kubernetes and EKS engineers
- DevOps and SRE engineers
- Infrastructure engineers and technical leads
- Engineers transitioning into platform architecture
- Engineers learning AI infrastructure patterns

---

## About the Author

This repository is maintained by **Arun**, an experienced AWS Cloud Architect and infrastructure architect with more than a decade of experience designing, building, operating, and improving enterprise infrastructure platforms.

His areas of expertise include:

- **AWS cloud architecture** — multi-account organisations, networking, security, and scalable service design
- **Kubernetes and Amazon EKS** — cluster architecture, workload management, autoscaling, and operational practices
- **Terraform and Infrastructure as Code** — modular design, state management, and reproducible environments
- **GitOps and CI/CD** — Argo CD, ApplicationSets, synchronisation strategies, and automated delivery pipelines
- **Cloud networking** — VPC design, subnet strategy, routing, and security boundaries
- **Distributed systems and event-driven architecture** — Kafka, streaming platforms, and asynchronous patterns
- **Observability and monitoring** — metrics, logging, alerting, and tracing across infrastructure layers
- **Infrastructure security** — least-privilege access, secrets management, encryption, and compliance controls
- **Platform engineering** — internal developer platforms, golden paths, and infrastructure automation
- **Reliability and scalability** — availability design, capacity planning, failure handling, and disaster recovery

Arun is actively expanding the repository into AI infrastructure topics, including GPU workload scheduling, NVIDIA device plugins, AI model hosting on Kubernetes, ML infrastructure, MLOps platforms, autoscaling AI workloads, and model observability.

---

## What This Repository Teaches

Each section in this repository is designed to build architectural understanding, not just operational familiarity. After working through the material, engineers and architects should understand:

- How infrastructure components fit together at the architecture level
- Why specific design decisions are made and what trade-offs they involve
- How infrastructure is automated, versioned, and made reproducible
- How GitOps and CI/CD pipelines are implemented and how they handle failure
- How workloads are deployed, operated, and recovered
- How drift, failure, rollback, scaling, and recovery behave in practice
- How production-readiness differs from simply deploying a working application
- What observability, security, and networking considerations apply to each pattern

---

## Repository Contents

| Area | Description | Documentation |
|---|---|---|
| GitOps and Argo CD Reference Architectures | Argo CD deployment patterns covering CLI-managed Applications, the App-of-Apps pattern, and ApplicationSets. Includes synchronisation strategies, self-healing, drift detection, rollback, and failure scenarios validated on a standalone Kubernetes cluster. | [View documentation](./argocd-reference-architectures/README.md) |
| Terraform Infrastructure Patterns | Modular Terraform for AWS infrastructure. Current implementation covers a production-oriented multi-AZ VPC with public and private subnet tiers, and secure S3 buckets with encryption, versioning, lifecycle policies, and optional Object Lock. Remote state and locking via S3 and DynamoDB. | [View documentation](./terraform/README.md) |

---

## Architecture Principles

The implementations in this repository are guided by the following principles.

**Everything as Code**
Infrastructure, configuration, and deployment definitions are written as code, committed to Git, and managed through automated pipelines. Manual configuration is avoided.

**Automation over Manual Configuration**
Repetitive operations are automated. Manual steps introduce inconsistency, are not reproducible at scale, and create operational risk.

**Reproducibility**
Any environment described in this repository can be recreated consistently from the same inputs. This applies to infrastructure, application deployment, and operational tooling.

**Security by Design**
Security controls are applied at the design stage, not added after the fact. Access is restricted to the minimum required. Encryption, isolation, and audit trails are defaults, not options.

**Least Privilege**
Components, identities, and workloads are granted only the permissions they require to function. Over-permissioned roles and policies are an architecture defect.

**Observability by Default**
Infrastructure and workloads are designed to be observable. Metrics, logs, and health signals are built in, not retrofitted.

**Git as the Source of Truth**
The desired state of infrastructure and applications is defined in Git. The cluster or cloud environment reflects Git, not the other way around. Drift from Git is a defect.

**Immutable and Repeatable Deployments**
Deployments use versioned, immutable artefacts. Upgrading means replacing, not patching in place.

**Failure-Aware Architecture**
The design accounts for failure. Recovery paths, rollback strategies, and blast-radius isolation are considered during design, not only during incidents.

**Scalability**
Patterns are designed to scale without requiring structural changes. ApplicationSets, modular Terraform, and parameterised templates are examples of this principle in practice.

**Operational Simplicity**
Architecture choices favour operational clarity. A simpler, well-understood design that teams can reason about is preferable to a clever design that introduces cognitive overhead.

**Documentation as Part of Architecture**
Architecture decisions, design rationale, and operational procedures are documented alongside the implementation. Code without documentation transfers knowledge poorly.

---

## Production-Readiness Focus

A working deployment is not the same as a production-ready deployment. This repository addresses the concerns that separate the two.

Production infrastructure requires explicit design decisions across the following areas:

| Concern | What it involves |
|---|---|
| Availability | Multi-AZ placement, replica configuration, health checks, and service continuity |
| Resilience | Failure isolation, self-healing, circuit breaking, and graceful degradation |
| Security | Least-privilege access, network segmentation, secrets management, and encryption at rest and in transit |
| Networking | Subnet strategy, routing, egress control, service exposure, and DNS |
| Secrets management | Avoiding hardcoded credentials, using secret stores, and rotating secrets safely |
| Upgrade strategies | Zero-downtime updates, rolling deployments, canary patterns, and Kubernetes version upgrades |
| Rollback | Detecting degraded deployments, reverting to a known-good state, and validating recovery |
| Disaster recovery | State backup, RTO and RPO targets, and recovery procedures |
| Monitoring | Cluster, workload, infrastructure, and application-level metrics |
| Logging | Centralised log collection, retention, and querying |
| Alerting | Threshold-based and anomaly-based alerts with actionable runbooks |
| Cost awareness | Right-sizing, idle resource elimination, and cost attribution by team or workload |
| Capacity planning | Understanding growth patterns and provisioning ahead of demand |
| Operational ownership | Clear ownership of infrastructure components, runbooks, and incident response |

Where relevant, each section in this repository addresses applicable production concerns directly.

---

## Roadmap

The following areas are planned for addition. Items listed here are planned directions and are not yet implemented unless explicitly documented in a folder.

- Advanced Kubernetes architecture patterns
- Multi-cluster GitOps with Argo CD
- AWS and EKS platform patterns
- Amazon EKS cluster architecture and node group design
- Observability stacks (metrics, logging, tracing)
- Infrastructure security patterns
- Kafka and event-driven platform architecture
- CI/CD pipeline architecture
- Service mesh patterns
- AI infrastructure on Kubernetes
- GPU workload scheduling and NVIDIA device plugin configuration
- AI model serving and inference deployment
- MLOps platform patterns
- Autoscaling AI workloads
- Infrastructure automation and platform engineering tooling
- Reliability engineering and chaos testing patterns

---

## How to Use This Repository

Each folder in this repository follows a consistent structure: overview, architecture, design decisions, implementation steps, validation, and failure scenarios. The suggested approach for each section is:

1. Read the folder README to understand the architecture and design intent.
2. Review the manifests or Terraform code to understand the implementation.
3. Examine the architecture decisions and understand the trade-offs.
4. Deploy in a safe, non-production environment.
5. Execute the validation steps to confirm the implementation behaves as expected.
6. Work through the failure and recovery scenarios to understand operational behaviour.
7. Review production considerations before adapting the pattern.
8. Adapt the pattern to your own organisational requirements, naming conventions, and constraints.

---

## Disclaimer

The implementations in this repository are provided for reference and learning purposes. Before using any pattern in a production environment:

- Review all manifests, Terraform code, and configuration against your organisation's security, compliance, and operational standards.
- Validate that versions, resource sizes, CIDR ranges, region selections, and access controls are appropriate for your environment.
- Assess cost implications for your workload profile and cloud account.
- Ensure that secrets, credentials, and sensitive configuration are managed according to your organisation's requirements and are never stored in version control.
- Test thoroughly in a non-production environment before applying to production workloads.

The author accepts no liability for issues arising from use of these implementations in production environments.
