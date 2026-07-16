# Jenkins Image Build Pipeline — Runbook

**Repo:** `https://github.com/Github-Arun-Repo/platform-engineering-reference-architectures.git`
**Base folder:** `cicd-reference-architectures/` (run commands from this folder)
**Cluster:** Standalone K8s on EC2 · **Jenkins UI:** `http://<EC2-IP>:30080`

---

## Repo Layout (all paths below match this)

```
cicd-reference-architectures/
├── sample-application/
│   ├── src/main/java/com/example/app/
│   │   ├── TodoApplication.java
│   │   ├── Todo.java
│   │   ├── TodoController.java
│   │   └── TodoRepository.java
│   ├── Dockerfile                    # multi-stage build
│   └── pom.xml                       # Spring Boot 3.2 / Java 21
└── phase-1-image-build-jenkins/
    ├── Jenkinsfile                   # 8-stage pipeline
    ├── README.md
    ├── installation-jenkins.md
    └── jenkins-demo-runbook.md       # ← this file
```

---

## Installation: Deploy Jenkins

Follow the complete installation guide: **[installation-jenkins.md](./installation-jenkins.md)**

That document covers:
- Helm installation on Kubernetes
- Plugin configuration
- Docker access for builds
- Docker registry credentials
- Pipeline job creation

After completing installation, return here and continue with the pre-flight section.

---

## 0. PRE-FLIGHT

Run these checks before starting. Jenkins must already be installed and healthy.

Credential prerequisites (mandatory):
- Jenkins credential `github-credentials` exists and has read access to the GitHub repository used by the job
- Jenkins credential `dockerhub-credentials` exists and has push access to Docker Hub repo `agovindasamy/arun`
- Job SCM configuration uses credential `github-credentials`

```bash
# Local clone current? Pull from repo root, then move into the working directory
cd ~/platform-engineering-reference-architectures && git pull
cd cicd-reference-architectures    # all commands below run from here

# Jenkins pod running?
kubectl get pods -n jenkins        # expect Running 1/1

# Jenkins UI accessible?
curl -s -o /dev/null -w "%{http_code}" http://<EC2-IP>:30080/login
# Expect: 200

# Docker working on the node?
docker version
docker info | grep "Server Version"

# Credentials configured?
# Check Jenkins UI → Manage Jenkins → Credentials:
#   - github-credentials
#   - dockerhub-credentials
```

**Timing plan:**
- Installation (one-time): ≈ 15 min
- Pre-flight: ≈ 3 min
- Part 1 — Pipeline execution walkthrough: ≈ 20 min
- Part 2 — Failure and recovery: ≈ 15 min
- Part 3 — Operational patterns: ≈ 10 min
- **Total runbook time (without installation): ≈ 48 min**

---
---

# PART 1 — Pipeline Execution (≈20 min)

> Goal: run the full pipeline end-to-end and understand what each stage does.

## 1.1 — Read the Jenkinsfile Before Running

Always read the pipeline before running it — the Jenkinsfile is code, not configuration.

```bash
cat phase-1-image-build-jenkins/Jenkinsfile
```

Notice the structure:
- `environment {}` block — all image names, registry, and tags in one place; change once to affect every stage
- `options {}` block — build retention, 30-minute timeout, timestamps on every log line
- Stage order — tests before image build, scan before push (cheap checks first, expensive operations last)
- `post {}` block — cleanup and notifications fire regardless of success or failure

## 1.2 — Trigger the First Build

In the Jenkins UI:
1. Open `todo-app-image-build` job
2. Click **Build Now**
3. Watch the **Stage View** update in real time

As each stage runs, here is what is happening:

```
[Checkout] Running...
  → Cloning the repository, checking out main branch

[Build & Test] Running...
  → mvn clean test — compiles and runs all unit tests
  → Pipeline stops here if any test fails (fail fast — no broken code proceeds further)

[Code Quality] Running...
  → SonarQube static analysis (or a skip message if SonarQube is not configured)

[Build Application] Running...
  → mvn clean package -DskipTests
  → Produces: target/todo-app-0.0.1-SNAPSHOT.jar

[Build Docker Image] Running...
  → docker build using the multi-stage Dockerfile
  → Two tags produced: todo-app:1 and todo-app:latest

[Scan Docker Image] Running...
  → trivy image todo-app:1
  → Reports any CVEs found; pipeline continues in warn-only mode

[Push to Registry] Running...
  → docker login (credentials injected from Jenkins, never visible in logs)
  → docker push todo-app:1
  → docker push todo-app:latest
  → docker logout immediately after

[Update Deployment Manifests] Running...
  → Placeholder for Phase 2 ArgoCD integration
```

```bash
# In the console output, confirm:
# "Building Docker image: arunrepo/todo-app:1"
# "Successfully built ..."
# "Image built and pushed: arunrepo/todo-app:1"
```

👉 Green pipeline. Every stage passed. Build number 1 is now in the registry.

## 1.3 — Inspect the Resulting Image

```bash
# What images were built?
docker images | grep todo-app

# Inspect the image metadata
docker inspect arunrepo/todo-app:1 | jq '.[0].Config'

# Verify non-root user
docker run --rm arunrepo/todo-app:1 whoami
# Expect: appuser (not root)

# Check health check config
docker inspect arunrepo/todo-app:1 | jq '.[0].Config.Healthcheck'

# Check image size — multi-stage keeps it small
docker images arunrepo/todo-app:1 --format "Size: {{.Size}}"
```

👉 Image runs as `appuser`. Health check is configured. Size is ~180MB compared to `eclipse-temurin:21-jdk-alpine` at ~330MB — the build tools are excluded from the final image by the multi-stage build.

## 1.4 — Run the Image Locally

```bash
docker run -d -p 8080:8080 --name todo-demo arunrepo/todo-app:1

# Wait ~5 seconds for startup
sleep 5
curl -s http://localhost:8080/api/todos/health
# Expect: "TODO App is healthy"

# Create a todo
curl -s -X POST http://localhost:8080/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Learn Jenkins", "description": "Pipeline demo", "completed": false}' | jq .

# List todos
curl -s http://localhost:8080/api/todos | jq .

# Clean up
docker stop todo-demo && docker rm todo-demo
```

👉 The image is functional — not just built and pushed. Running it locally is the fastest way to confirm the artifact is correct before it reaches any environment.

## 1.5 — Inspect Build Artifacts and History

In the Jenkins UI:
- Open the build → **Console Output** — full log, every command, every line, timestamped
- Back to job → **Stage View** — visual pipeline with per-stage timing
- **Build Artifacts** section — the JAR file archived from the `post` block

```bash
# Jenkins REST API — query the build result
curl -s "http://<EC2-IP>:30080/job/todo-app-image-build/1/api/json" | jq '.result,.duration'
# Expect: "SUCCESS" and duration in milliseconds
```

👉 Every build is queryable via the API. Build number → Jenkins URL → console output → Git commit. The full audit trail exists without any extra tooling.

---
---

# PART 2 — Failure and Recovery Scenarios (≈15 min)

> Goal: understand how the pipeline fails, why, and how to recover.

## 2.1 — Failing Test (Stage 2 Fail Fast)

The most common pipeline failure is a developer pushing broken code. Let's see exactly what happens.

```bash
# Break a test — edit the controller to return null
cd ~/platform-engineering-reference-architectures
sed -i 's/return ResponseEntity.ok(todos);/return ResponseEntity.ok(null);/' \
  cicd-reference-architectures/sample-application/src/main/java/com/example/app/TodoController.java

git add -A && git commit -m "break: return null from controller (demo)" && git push
```

Trigger a build. In the Stage View:

```
[Checkout]        ✅
[Build & Test]    ❌ FAILED
```

👉 The pipeline stops at stage 2. Stages 3–8 (Docker build, scan, push) never execute. A broken image never reaches the registry. The cost is 30–60 seconds of CI time, not a bad image in production.

```bash
# In the console output, look for:
# "BUILD FAILURE"
# "Tests run: X, Failures: Y"

# Recover immediately
git revert --no-edit HEAD && git push
```

Trigger another build — back to green.

## 2.2 — Build Succeeds, Container Crashes (Pipeline Success ≠ App Health)

The pipeline passes and the image is in the registry — but does the container actually run?

```bash
# Simulate a runtime crash — JVM OOM at startup
docker run --rm -e JAVA_TOOL_OPTIONS="-Xmx1m" arunrepo/todo-app:1
# Container starts but JVM crashes immediately

# Run it with a health check to see the health status
docker run -d --name todo-broken \
  -e JAVA_TOOL_OPTIONS="-Xmx1m" \
  -p 8081:8080 arunrepo/todo-app:1

sleep 15
docker inspect todo-broken | jq '.[0].State.Health.Status'
# Expect: "unhealthy"

docker stop todo-broken && docker rm todo-broken
```

👉 The pipeline produced a valid image — the build was correct. But the container is unhealthy at runtime. This is the distinction between **pipeline success** and **application health**. This exact gap is what Kubernetes liveness/readiness probes and ArgoCD health checks address — covered in Phase 2.

## 2.3 — Trivy Finds a Vulnerability (Scan Stage)

```bash
# Run Trivy manually against the built image
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image --severity HIGH,CRITICAL arunrepo/todo-app:1
```

👉 If vulnerabilities are found, Trivy reports the library, CVE ID, severity, and the fixed version. In the current Jenkinsfile the scan is warn-only — the pipeline continues. To make the pipeline fail and block the push on a HIGH/CRITICAL CVE, change the scan step to:

```groovy
sh '''
    trivy image --severity HIGH,CRITICAL --exit-code 1 ${IMAGE_NAME}:${IMAGE_TAG}
'''
```

With `--exit-code 1`, a vulnerable image never reaches the registry. This is supply chain security enforced at the pipeline level.

## 2.4 — Registry Push Failure (Wrong Credentials)

What happens if the Docker credentials are wrong or expired?

In Jenkins UI:
1. Go to **Manage Jenkins → Credentials**
2. Temporarily corrupt the Docker password
3. Trigger a build

```
[Checkout]             ✅
[Build & Test]         ✅
[Code Quality]         ✅
[Build Application]    ✅
[Build Docker Image]   ✅
[Scan Docker Image]    ✅
[Push to Registry]     ❌ FAILED — "unauthorized: authentication required"
```

👉 All stages before the push succeeded — the image was built, tested, and scanned. Only the push failed. Restore the correct credentials and re-trigger the build. The pipeline picks up at the failed stage without rebuilding the image from scratch.

---
---

# PART 3 — Operational Patterns (≈10 min)

## 3.1 — Triggering a Second Build (Immutable Versioning)

Every commit produces a new, independently versioned image artifact.

```bash
# Bump the application version
sed -i 's/version>0.0.1-SNAPSHOT/version>0.0.2-SNAPSHOT/' \
  cicd-reference-architectures/sample-application/pom.xml

git add -A && git commit -m "bump version to 0.0.2-SNAPSHOT" && git push
```

After the build completes:

```bash
docker images | grep todo-app
# todo-app:1        (build 1 — still exists)
# todo-app:2        (build 2 — new artifact)
# todo-app:latest   (points to build 2)
```

👉 Build 2 is a new immutable artifact. Build 1 is unchanged and still pullable. Rolling back is just redeploying the earlier image tag — no rebuild required.

## 3.2 — Build History and Traceability

```bash
# List recent builds via Jenkins REST API
curl -s "http://<EC2-IP>:30080/job/todo-app-image-build/api/json?tree=builds[number,result,timestamp]" \
  | jq '.builds[] | {build: .number, result: .result}'

# Trace a build number back to its Git commit
curl -s "http://<EC2-IP>:30080/job/todo-app-image-build/2/api/json" \
  | jq '.actions[] | select(._class | contains("RevisionParameterAction")) | .parameters'
```

👉 Build number → Jenkins URL → Git commit. Every image in the registry is traceable to the exact commit that produced it. This traceability is the foundation of safe rollbacks and incident investigations.

## 3.3 — Webhook-Triggered Build (Automatic CI)

Configure GitHub to trigger builds automatically on every push — no manual click, no polling.

In GitHub:
1. Go to Repository → **Settings → Webhooks**
2. Add webhook: `http://<EC2-IP>:30080/github-webhook/`
3. Content type: `application/json`
4. Events: **Push**

```bash
# Test the webhook — make a small change and push
echo "# webhook test" >> cicd-reference-architectures/sample-application/README.md
git add -A && git commit -m "test webhook trigger" && git push
```

👉 In the Jenkins UI, a build starts within seconds of the push — no polling delay, no manual action. Every push to `main` automatically tests, builds, scans, and publishes a versioned image. The developer's work ends at `git push`.

---
---

## RESET (clean slate to repeat or restart)

```bash
# Remove local demo images
docker rmi arunrepo/todo-app:1 arunrepo/todo-app:2 arunrepo/todo-app:latest 2>/dev/null || true

# Revert any code changes made during the runbook
cd ~/platform-engineering-reference-architectures
git checkout cicd-reference-architectures/sample-application/pom.xml
git checkout cicd-reference-architectures/sample-application/src/

# Optionally clear Jenkins build history:
# Jenkins UI → todo-app-image-build → Delete Build History
```

---

## Command Cheat-Sheet

| Intent | Command |
|---|---|
| Check Jenkins pod | `kubectl get pods -n jenkins` |
| Get admin password | `kubectl exec -n jenkins <pod> -- cat /run/secrets/additional/chart-admin-password` |
| List builds (API) | `curl http://<IP>:30080/job/<job>/api/json` |
| Trigger build (API) | `curl -X POST http://<IP>:30080/job/<job>/build --user admin:<token>` |
| Check image locally | `docker run --rm -p 8080:8080 <image>:<tag>` |
| Scan image locally | `trivy image --severity HIGH,CRITICAL <image>:<tag>` |
| Inspect image | `docker inspect <image>:<tag> \| jq '.[0].Config'` |
| View image layers | `docker history <image>:<tag>` |
| Check non-root user | `docker run --rm <image>:<tag> whoami` |
| Jenkins logs | `kubectl logs -n jenkins <pod>` |
