# Jenkins Image Build Pipeline

---

## What Is This?

This section demonstrates a **container image build pipeline** implemented with Jenkins — one of the most widely deployed CI orchestrators in the industry.

The pipeline takes a Spring Boot application from source code, compiles and tests it, builds a production-quality Docker image, scans it for vulnerabilities, and pushes it to a registry. The result is an immutable, versioned container artifact ready for deployment.

Beyond just showing the pipeline code, this documentation teaches the **architectural reasoning**: how Jenkins models a CI pipeline, why stages are ordered the way they are, what each stage exists to prevent, and how to operate the pipeline in production.

---

## Quick Start — Choose Your Path

**I want to install Jenkins first:**
→ [Follow the installation guide](./installation-jenkins.md)

**I want to run the pipeline hands-on:**
→ [Follow the demo runbook](./jenkins-demo-runbook.md)

**I want to understand Jenkins pipeline concepts:**
→ [Continue reading below](#jenkins-pipeline-fundamentals)

**I want to understand how the stages work:**
→ [Jump to pipeline architecture](#pipeline-architecture)

---

## Jenkins Pipeline Fundamentals

### What Jenkins Is

Jenkins is a **build orchestrator** — a server that runs automated jobs triggered by events (a Git push, a schedule, a webhook, a manual click). It is not opinionated about what those jobs do. It runs shell commands, calls APIs, builds code, deploys infrastructure, or anything else you script.

Jenkins became the CI industry standard because:
- It runs anywhere: on-premises, cloud VMs, or Kubernetes
- It can orchestrate any tool via shell or plugin
- Its Jenkinsfile is version-controlled alongside application code
- It has a plugin ecosystem of 1,800+ integrations

### The Declarative Pipeline

Modern Jenkins uses **Declarative Pipeline** syntax — a structured DSL defined in a `Jenkinsfile` at the root of your repository. The pipeline is declared, not scripted:

```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
    }
}
```

The Jenkinsfile lives in Git alongside application code. This means:
- Every pipeline change is a commit
- You can code review pipeline changes
- You can roll back a broken pipeline with `git revert`

### Agents and Executors

Jenkins runs jobs on **agents** — machines (or containers) that execute build steps. The controller (Jenkins server) orchestrates; agents do the work.

| Agent type | How it works | Use case |
|---|---|---|
| **any** | Run on any available agent | Simple builds |
| **label** | Run on agents with a specific label | Specialized hardware |
| **kubernetes** | Spawn a pod, run inside it, delete on completion | Scalable, ephemeral builds |

For production, use Kubernetes agents — they scale on demand, are isolated per build, and are discarded after use (no stale state).

### Stages, Steps, and the Post Block

A Jenkins pipeline is a sequence of **stages**. Each stage contains **steps** (commands to run). After all stages, the **post** block handles outcomes:

```groovy
pipeline {
    stages {
        stage('Build') { steps { sh 'mvn test' } }
        stage('Push')  { steps { sh 'docker push ...' } }
    }
    post {
        success { echo "Done!" }
        failure { echo "Failed!" }
        cleanup { cleanWs() }
    }
}
```

Stages provide visual progress, isolated failure reporting ("failed at Stage 4"), and time tracking per stage.

---

## Pipeline Architecture

```
Checkout
    -> Scan Repository Secrets with Gitleaks
    -> Scan Filesystem with Trivy
    -> Unit Tests & Code Coverage
    -> SonarQube Analysis Placeholder (currently disabled)
    -> Build Application
    -> Build Docker Image
    -> Generate Image SBOM
    -> Scan SBOM with Grype
    -> Scan Docker Image with Trivy
    -> Commit Security Reports
    -> Enforce Security Gates
    -> Push to Registry
    -> Sign Image with Cosign (optional)
    -> Attest Image with Cosign (optional)
    -> Attach SBOM to Image
    -> Commit Cosign Evidence (optional)
    -> Update Deployment Manifests
```

### Why This Stage Order?

The order is deliberate. Each stage filters defects before they reach the next, more expensive stage:

| Stage | Purpose in the current pipeline |
|-------|-------------------------------|
| Checkout | Pull the exact source revision |
| Scan Repository Secrets | Detect committed credentials before doing any build work |
| Scan Filesystem with Trivy | Run source and dependency-oriented checks before packaging or image creation |
| Unit Tests & Code Coverage | Validate behavior and generate JaCoCo evidence |
| SonarQube Placeholder | Reserved for source-level SAST and quality gates |
| Build Application | Create the packaged Spring Boot JAR |
| Build Docker Image | Build the deployable runtime image |
| Generate Image SBOM | Create CycloneDX, SPDX, and table SBOM outputs |
| Scan SBOM with Grype | Evaluate package inventory for vulnerability risk |
| Scan Docker Image | Evaluate runtime image layers for vulnerabilities |
| Commit Security Reports | Publish report evidence to Git and the dashboard |
| Enforce Security Gates | Block promotion when gating policies fail |
| Push to Registry | Publish the image only after gates pass |
| Sign / Attest with Cosign | Add digest signatures and verifiable predicates when enabled |
| Attach SBOM | Attach CycloneDX SBOM as an OCI artifact |
| Commit Cosign Evidence | Publish signing evidence to Git and the dashboard |

**Design principle:** source-level checks such as secret detection and filesystem analysis should fail fast, before packaging and image creation, while report evidence is still published before promotion so engineers can inspect what happened.

---

## Understanding the Jenkinsfile

### Image Versioning Strategy

```groovy
IMAGE_TAG = "${BUILD_NUMBER}"     // 1, 2, 3, 42 — unique per build
LATEST_TAG = 'latest'             // convenience tag, always current
```

Two tags per image:
- **Build number** — lets you pin to a specific build and trace it back to a Jenkins run
- **latest** — lets Kubernetes always pull the most recent image without knowing the build number

In production, also add the Git commit SHA for full traceability:
```groovy
IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT[0..7]}"  // e.g. 42-abc1234
```

### Credential Handling

```groovy
withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials',
                                   usernameVariable: 'DOCKER_USER',
                                   passwordVariable: 'DOCKER_PASS')]) {
    sh 'echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin'
    sh 'docker push ${IMAGE_NAME}:${IMAGE_TAG}'
    sh 'docker logout'
}
```

Credentials are injected at runtime from the Jenkins credential store. They are never:
- Stored in Git
- Visible in build logs (Jenkins masks them)
- Baked into the Docker image

`docker logout` ensures no session token persists on the agent after the build.

### Build Options

```groovy
options {
    buildDiscarder(logRotator(numToKeepStr: '15'))  // keep last 15 builds
    timeout(time: 30, unit: 'MINUTES')              // kill hung builds
    timestamps()                                     // prepend timestamps to logs
}
```

These are important operational hygiene:
- **buildDiscarder** — prevents unbounded disk growth on the Jenkins PV
- **timeout** — prevents hung builds from occupying agents indefinitely
- **timestamps** — essential for correlating build logs with external events

---

## The Docker Image: What Makes It Production-Ready

The Dockerfile uses **multi-stage builds** to produce a minimal runtime image:

```
Stage 1 — Builder (eclipse-temurin:21-jdk-alpine)
  Installs Maven, compiles source code, extracts JAR layers
  ↓ discarded after build

Stage 2 — Runtime (eclipse-temurin:21-jre-alpine)
  Copies only app code + libraries from Stage 1
  Runs as non-root user (appuser)
  Exposes port 8080
  Sets HEALTHCHECK
  ↓ this is the final image pushed to registry
```

**Why multi-stage matters:**

| Concern | Single-stage | Multi-stage |
|---------|-------------|-------------|
| Image size | ~450 MB (includes JDK, Maven) | ~180 MB (JRE only) |
| CVE surface | High (build tools have CVEs) | Low (minimal runtime) |
| Attack surface | Source code exposed | No source code in image |
| Build secrets | Risk of leaking into image | Stage discarded |

---

## Vulnerability Scanning with Trivy

Trivy is the 2026 standard for container image CVE scanning. The pipeline stage:

```bash
trivy image --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}
```

Checks:
- **OS packages** — Alpine packages with known CVEs
- **Java libraries** — JAR files in the application classpath
- **Severity filtering** — only reports HIGH and CRITICAL (ignoring noise)

**Operational decision — should a CVE fail the build?**

| Environment | Policy |
|-------------|--------|
| Development | Warn but continue |
| Staging | Fail on CRITICAL |
| Production | Fail on HIGH + CRITICAL |

Start conservative (warn), tighten as the team understands the vulnerability landscape.

---

## Operational Patterns

### Build Triggers

| Trigger | Configuration | Use case |
|---------|-------------|----------|
| Manual | Click "Build Now" | Testing pipeline changes |
| GitHub Webhook | GitHub → Settings → Webhooks | Auto-build on push |
| Poll SCM | `triggers { pollSCM('H/5 * * * *') }` | When webhooks not available |
| Scheduled | `triggers { cron('H 2 * * *') }` | Nightly dependency scans |

**Prefer webhooks.** They fire in seconds after a push. SCM polling adds minutes of latency and wastes compute.

### Parallel Stages

Independent work can run concurrently:

```groovy
stage('Parallel Checks') {
    parallel {
        stage('Unit Tests')   { steps { sh 'mvn test' } }
        stage('Code Quality') { steps { withSonarQubeEnv(...) { sh 'mvn sonar:sonar' } } }
    }
}
```

This reduces total pipeline time when both stages take 60 seconds — they finish in 60 seconds total rather than 120 seconds.

---

## Real-World Considerations

**Registry credentials**
Never use a Docker Hub password. Create a Personal Access Token (PAT) with only `write:packages` and `read:packages` permissions. Rotate quarterly.

**Jenkins in production**
- Builds should run on ephemeral Kubernetes agents, not the controller node
- Jenkins configuration should be in Git (Jenkins Configuration as Code plugin)
- Monitor Jenkins health with Prometheus and Grafana

**Image promotion across environments**
Build once, retag to promote. The same image runs in dev, staging, and production — retagging it, not rebuilding:

```bash
docker tag todo-app:42 todo-app:staging-42
docker push todo-app:staging-42
```

---

## Key Takeaways

1. **Jenkins is an orchestrator** — it runs whatever you script; the value is in the pipeline design

2. **Fail fast** — cheap stages (test) always precede expensive stages (push to registry)

3. **Credentials are never in code** — the Jenkins credential store injects them at runtime

4. **Multi-stage Docker builds** produce smaller, safer images without build tools in production

5. **Image scanning is mandatory** — CVEs in OS packages and libraries are the most common supply chain risk

6. **Version every image** — build number + Git SHA gives you full traceability from cluster back to commit

7. **The Jenkinsfile is code** — review it, version it, and treat it with the same discipline as application code

---

## Related Documentation

- [Installation Guide](./installation-jenkins.md) — Jenkins on Kubernetes, complete setup
- [Demo Runbook](./jenkins-demo-runbook.md) — Hands-on walkthrough
- [GitHub Actions Implementation](../phase-1-image-build-github-actions/) — Same pipeline, different tool
- [Main CI/CD README](../README.md) — Tool comparison and selection guide
- [Sample Application](../sample-application/) — The application being built
