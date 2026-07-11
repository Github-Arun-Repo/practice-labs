# Argo CD and GitOps Reference Architectures

## What Is This?

This section contains three production-validated Argo CD deployment patterns, each addressing a different layer of infrastructure orchestration complexity. The patterns progress from direct application management, to hierarchical composition, to scalable multi-environment deployment.

Beyond just showing code, this documentation teaches the architectural reasoning: why each pattern exists, when to use it, what trade-offs it makes, and how to operate it in production.

---

## GitOps Principles

Before exploring patterns, understand the core GitOps philosophy:

**Git as the Source of Truth**
The desired state of your infrastructure and applications is declared in Git. The cluster's state should match Git — no more, no less.

**Declarative Infrastructure**
You describe what you want, not the steps to get there. "I want three nginx replicas" rather than "run these three kubectl commands."

**Continuous Reconciliation**
An operator (Argo CD) continuously compares Git to the cluster. If they diverge, the operator corrects the cluster. This is enforcement, not just monitoring.

**Audit Trail**
Every change goes through Git. Every deployment has a commit. Every rollback is a revert. You have a complete history of infrastructure changes.

**Reduced Manual Toil**
Deployments happen automatically on Git commits. No SSH to servers, no manual `kubectl apply`. Humans write code; machines execute it.

---

## Understanding Argo CD Fundamentals

### The Application CRD

At the heart of Argo CD is the Application custom resource — a Kubernetes object that binds three things together:

1. **Git Source** — a repository, path, and revision (branch/tag/commit)
2. **Cluster Destination** — which cluster and namespace to deploy to
3. **Sync Policy** — how and when to reconcile

An Application watches Git and continuously compares the manifests in Git against what's running in the cluster. When they differ, it's "OutOfSync." When they match, it's "Synced."

### Sync State vs. Health State

Argo CD tracks two independent dimensions:

| Dimension | Meaning | Example |
|-----------|---------|---------|
| **Sync State** | Does the cluster match Git? | Synced, OutOfSync, Unknown |
| **Health State** | Are the deployed resources healthy? | Healthy, Progressing, Degraded |

An Application can be **Synced but Degraded** (Git and cluster match, but the deployment is broken) or **OutOfSync but Healthy** (cluster has changes Git doesn't know about, but nothing is broken). Understanding this distinction is critical for troubleshooting.

### Sync Policies

How Argo CD reacts to drift is controlled by sync policy:

| Policy | Behavior | Use Case |
|--------|----------|----------|
| **manual** | Reports drift; waits for human approval to sync | Production where changes need review |
| **automated** | Automatically syncs when Git changes | Safe CI/CD environments |
| **automated + selfHeal** | Auto-syncs Git changes AND reverts cluster drift | Strict GitOps: cluster is read-only except through Git |
| **automated + selfHeal + prune** | Also deletes resources removed from Git | Full GitOps with automatic cleanup |

**The conservative approach:** Start with `manual` sync. Add `selfHeal` once the team understands the pattern. Add `prune` only when you're confident in Git as the source of truth.

---

## The Three Patterns: When to Use Each

The three patterns form a progression. Understanding when to use each prevents future rearchitecting.

### Pattern 1: Direct Application Management (CLI / Declarative)

**What it is:**
Individual Application manifests, each declaring one or more workloads. Applications are created directly via the CLI or by applying YAML to the cluster.

**When to use:**
- Small, independent applications (< 10 apps)
- Each application has different deployment requirements
- Need fine-grained control over each Application's sync policy
- Team prefers explicit, one-file-per-app structure

**When NOT to use:**
- Deploying the same application across many environments (repetition)
- Scaling to 50+ applications (configuration explosion)
- Generators or parameterized deployments needed

**Operational overhead:**
- Add a new app? Write a new Application YAML.
- Change a sync policy? Edit the file directly.
- Scale to many apps? Creates folder chaos.

**Example use case:**
A platform with 5–8 carefully curated services, each managed by a different team. Each team owns their Application file.

---

### Pattern 2: App of Apps (Hierarchical Composition)

**What it is:**
A parent Application points to a directory of child Applications. Argo CD deploys the parent, which automatically manages all children. Control is hierarchical: the parent is the single entry point.

**When to use:**
- 10–50 applications
- Applications are grouped by domain, environment, or team
- Need a single "root" to manage the entire set
- Some applications share configuration or rollout decisions
- Want to group related applications for easier management

**When NOT to use:**
- Very small number of apps (use Pattern 1 directly)
- Need to deploy the same app template many times (use Pattern 3)
- Dynamic app generation needed

**Operational overhead:**
- Add a new app? Create an Application YAML in `children/` and add it to `kustomization.yaml`.
- Change a sync policy? Edit the individual child or the parent (cascades to all children).
- Scales to ~50 apps before folder organization becomes awkward.

**Example use case:**
A platform serving three product lines. Each line has 10–15 microservices. Parent Application "product-line-alpha" manages all alpha services; Argo CD and the ops team only think about the parent.

**Important:** When you delete a parent Application with cascading delete enabled, all children and their workloads are deleted. This is by design but requires discipline.

---

### Pattern 3: ApplicationSet (Scalable, Parameterized Generation)

**What it is:**
A template combined with a generator. The generator supplies parameters; ApplicationSet instantiates the template once per parameter set. Generators can be lists, Git directories, registered clusters, or matrix products.

**When to use:**
- 50+ similar applications
- Deploying the same app across many environments
- Multi-cluster deployments (one ApplicationSet, N clusters)
- Need dynamic application generation
- Applications are generated from a Git directory structure

**When NOT to use:**
- Each app has radically different requirements
- Applications rarely scale; use Pattern 1 or 2 instead

**Operational overhead:**
- Add a new app? Add one list element (3–5 lines) to the generator.
- Scales gracefully to hundreds of applications.
- If the generator breaks, all generated apps fail; blast radius is large but isolated.

**Generator types:**
- **List**: Hard-coded list of parameters (useful for environments)
- **Git directory**: One app per folder in Git (automatically scales)
- **Cluster**: One app per registered Argo CD cluster (multi-cluster pattern)
- **Matrix**: Cross-product of two generators (e.g., all apps × all regions)

**Example use case:**
A SaaS platform with 200+ customer microservices. Each customer deployment is an ApplicationSet-generated Application using the cluster generator, deploying to their dedicated namespace.

---

## Decision Framework: Which Pattern for Your Use Case?

Use this flowchart to decide:

1. **How many applications do you have (or expect to have)?**
   - 1–10: Pattern 1
   - 10–50: Pattern 2 or 1
   - 50+: Pattern 3 or Pattern 2 (grouped)

2. **Are the applications similar or diverse?**
   - Diverse, each unique: Pattern 1
   - Similar, grouped by domain: Pattern 2
   - Highly similar or repeated: Pattern 3

3. **Do you deploy to multiple clusters or environments?**
   - Single cluster, single environment: Pattern 1 or 2
   - Multiple clusters or environments: Pattern 3 (cluster or Git directory generator)

4. **How often are you adding/removing applications?**
   - Rarely (quarterly): Pattern 1 is fine
   - Frequently (weekly): Pattern 2 or 3 preferred
   - Dynamically (per customer, per region): Pattern 3 required

---

## Real-World Considerations

### Secrets and Sensitive Data

**Never store secrets in Git.** Use one of these approaches:

- **External Secrets Operator**: Syncs secrets from AWS Secrets Manager, HashiCorp Vault, etc.
- **Sealed Secrets**: Encrypts secrets in Git; only the cluster can decrypt
- **Kustomize secretGenerator** with external sourcing
- **Helm values** with a separate, non-Git secret store

### Separation of Concerns

- **Application maintainers** write Kubernetes manifests (`k8s/` folders)
- **Platform team** writes Application/ApplicationSet definitions (`argocd/` folders)
- **Cluster ops** manage Argo CD itself (installation, access, resource limits)

Each role has different Git permissions and responsibilities.

### Rollback and Safety

Rollback in Argo CD is simple: revert the Git commit and sync. No special rollback logic needed.

For safe rollbacks in production:
- Use branches for promotion (commit → staging → QA → production)
- Use manual sync policy in production; require approvals
- Combine with canary or blue-green deployments in the Application sync policy

### Monitoring and Observability

- Monitor Application health and sync state continuously
- Alert on OutOfSync (someone changed the cluster without Git)
- Alert on Degraded (deployment exists but is broken)
- Alert on reconciliation lag (Git change hasn't synced yet)

### Access Control

- Use Argo CD projects to restrict which teams can deploy to which namespaces
- Integrate with external auth (OIDC, LDAP, GitHub teams)
- Audit all deployments (Git commit author = who deployed)

---

## Learning Path

1. **Understand the pattern** — read the sections above
2. **See it in action** — follow [argocd-demo-runbook.md](./argocd-demo-runbook.md)
3. **Review the code** — inspect the manifests in `cli-demo/`, `app-of-apps-demo/`, `applicationset-demo/`
4. **Understand drift and recovery** — execute the failure scenarios in the runbook
5. **Design your own** — choose a pattern for your platform and adapt the code

---

## Repository Contents

| Folder | Pattern | What It Demonstrates |
|--------|---------|----------------------|
| `cli-demo/` | Pattern 1 | Direct Application management, drift detection, self-healing, prune |
| `app-of-apps-demo/` | Pattern 2 | Parent-child orchestration, hierarchical control, adding/removing children |
| `applicationset-demo/` | Pattern 3 | Template-driven generation, list generator, scaling to many apps |

Each demo includes:
- Application or ApplicationSet manifests
- Kubernetes workload manifests
- Operational scenarios (positive, negative, recovery)

---

## Installation and Setup

To install Argo CD and follow the demos:

1. [Install Argo CD](./installation-argocd.md) — complete setup guide
2. [Run the demo runbook](./argocd-demo-runbook.md) — 60-minute walkthrough with all three patterns

---

## Production Readiness Checklist

Before deploying Argo CD patterns to production:

- [ ] Argo CD itself is highly available (HA setup with multiple replicas)
- [ ] State is backed up (Argo CD database/configuration)
- [ ] Git repositories are accessible and have read access controls
- [ ] Secrets are managed separately from Git
- [ ] RBAC projects limit which teams can deploy where
- [ ] External auth (OIDC/LDAP) is integrated
- [ ] Monitoring alerts on sync state and health
- [ ] Runbook exists for incident response
- [ ] Change approval process is enforced (manual sync in prod)
- [ ] Rollback procedure is documented and tested

---

## Key Takeaways

1. **GitOps is about declaring desired state in Git and letting an operator enforce it.**

2. **Argo CD is the operator; Applications/ApplicationSets are the declarations.**

3. **Three patterns exist because different scales and scenarios need different approaches.**

4. **Drift detection and self-healing are powerful but require discipline — Git must be the source of truth.**

5. **Secrets, access control, and observability are not optional — they're part of production design.**

6. **Start with manual sync policy, add automation once the team understands the pattern.**

7. **Each pattern scales to a certain size; rearchitect when you outgrow it.**

---

## Related Documentation

- [Argo CD installation guide](./installation-argocd.md)
- [Live demo runbook](./argocd-demo-runbook.md)
- [Main repository README](../README.md)
- [Official Argo CD documentation](https://argo-cd.readthedocs.io/)
