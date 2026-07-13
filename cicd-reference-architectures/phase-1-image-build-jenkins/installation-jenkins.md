# Installing Jenkins on Kubernetes

This guide covers a complete Jenkins installation using Helm on a Kubernetes cluster, with Docker-in-Docker (DinD) capability to run container image build pipelines.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| Kubernetes cluster | 1.19+, `kubectl` configured with access |
| Helm | 3.x installed locally |
| Storage class | Default storage class available in the cluster |
| Outbound internet | Jenkins needs to download plugins on first run |
| Node IP / hostname | For NodePort UI access |

---

## Installation Steps

### 1. Create Namespace

```bash
kubectl create namespace jenkins
```

### 2. Add Jenkins Helm Repository

```bash
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
```

### 3. Install Jenkins using Helm

This installs Jenkins with the UI exposed via NodePort on port 30085, suitable for implementation and learning environments.

```bash
helm install jenkins jenkinsci/jenkins \
  --namespace jenkins \
  --set controller.serviceType=NodePort \
  --set controller.nodePort=30085 \
  --set controller.admin.username=admin \
  --set controller.persistence.storageClass="" \
  --set controller.persistence.accessMode=ReadWriteOnce \
  --set controller.persistence.size=8Gi
```

Wait for the Jenkins pod to be running:

```bash
kubectl get pods -n jenkins -w
```

Press Ctrl+C when the pod shows `Running` and `1/1` ready.

This typically takes 2–3 minutes on first start (Jenkins downloads plugins).

### 4. Get the Initial Admin Password

```bash
JENKINS_PASSWORD=$(kubectl exec -n jenkins \
  $(kubectl get pod -n jenkins -l app.kubernetes.io/name=jenkins -o name | head -1) \
  -- cat /run/secrets/additional/chart-admin-password)

echo "Jenkins admin password: $JENKINS_PASSWORD"
```

Save this password. You can retrieve it again at any time using the command above.

### 5. Access the Jenkins UI

Get your cluster node IP:

```bash
kubectl get nodes -o wide
```

Open in a browser:

```
http://<NODE-IP>:30085
```

Login with:
- **Username:** `admin`
- **Password:** (from Step 4)

### 6. Install Required Plugins

Navigate to: **Manage Jenkins → Plugins → Available Plugins**

Install the following plugins:

| Plugin | Purpose |
|--------|---------|
| Docker Pipeline | Build and push Docker images |
| Git | Clone repositories |
| Pipeline | Declarative Pipeline support |
| Credentials Binding | Inject secrets at runtime |
| Blue Ocean (optional) | Modern pipeline UI |
| SonarQube Scanner (optional) | Code quality integration |

Click **Install** and let Jenkins restart.

### 7. Configure Docker Access

Jenkins needs access to Docker to build images. Two approaches:

**Option A: Docker Socket Mount (Simplest)**

Patch the Jenkins deployment to mount the host Docker socket:

```bash
kubectl patch deployment jenkins -n jenkins --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {
      "name": "docker-socket",
      "hostPath": {"path": "/var/run/docker.sock"}
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts/-",
    "value": {
      "name": "docker-socket",
      "mountPath": "/var/run/docker.sock"
    }
  }
]'
```

**Option B: Docker-in-Docker Agent (Recommended for Production)**

Use a dedicated Docker-in-Docker agent pod. Configure under: Manage Jenkins → Clouds → Kubernetes → Pod Templates.

### 8. Add Docker Registry Credentials

Navigate to: **Manage Jenkins → Credentials → System → Global credentials → Add credentials**

| Field | Value |
|-------|-------|
| Kind | Username with password |
| Username | Your Docker Hub / registry username |
| Password | Docker Hub Personal Access Token (not password) |
| ID | `docker-credentials` |
| Description | Docker registry credentials |

### 9. Configure Git Repository Access

If the repository is private, add Git credentials:

Navigate to: **Manage Jenkins → Credentials → System → Global credentials → Add credentials**

| Field | Value |
|-------|-------|
| Kind | Username with password (HTTPS) or SSH Username with private key (SSH) |
| Username | GitHub username |
| Password / Private Key | GitHub Personal Access Token or SSH key |
| ID | `github-credentials` |

### 10. Create the Pipeline Job

1. Click **New Item**
2. Enter name: `todo-app-image-build`
3. Select **Pipeline**
4. Click **OK**
5. In configuration:
   - Under **Pipeline** → Definition: choose **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/Github-Arun-Repo/platform-engineering-reference-architectures.git`
   - Branch: `*/main`
   - Script Path: `cicd-reference-architectures/phase-1-image-build-jenkins/Jenkinsfile`
6. Click **Save**

---

## Verification

Confirm Jenkins is up and configured correctly:

```bash
# Jenkins pod running
kubectl get pods -n jenkins

# Jenkins reachable via NodePort
curl -s -o /dev/null -w "%{http_code}" http://<NODE-IP>:30085/login
# Expect: 200
```

Trigger a test build by clicking **Build Now** in the `todo-app-image-build` job. The first run will download Maven dependencies (may take 3–5 minutes). Subsequent runs use cache and complete faster.

---

## Post-Installation: Production Considerations

**Persistent Storage**
Ensure the Jenkins PVC is backed by a durable storage class. Loss of the Jenkins PV means losing build history, credentials, and job configuration.

```bash
kubectl get pvc -n jenkins
```

**TLS / HTTPS**
The default setup uses plain HTTP. In production, place Jenkins behind an ingress controller with a TLS certificate.

**RBAC and Authentication**
Restrict access to Jenkins:
- Enable role-based access (Manage Jenkins → Security → Authorization)
- Integrate with external SSO (LDAP, OIDC, GitHub OAuth)
- Limit who can trigger builds, read logs, and administer

**Backup**
Back up the Jenkins home directory regularly. The Helm chart PVC contains all configuration. For critical environments, use Jenkins Configuration as Code (JCasC) plugin to version-control Jenkins config in Git.

**Scaling Agents**
Jenkins controller should be small; heavy build work belongs in ephemeral agents. Configure Kubernetes pod templates to spawn agents on demand and delete them after builds complete.

---

## Uninstall Jenkins

```bash
helm uninstall jenkins -n jenkins
kubectl delete namespace jenkins
```

---

## Next Steps

After completing installation:

1. Return to [Jenkins Image Build Pipeline README](./README.md) to understand the pipeline architecture
2. Follow the [Jenkins Demo Runbook](./jenkins-demo-runbook.md) for a hands-on walkthrough
