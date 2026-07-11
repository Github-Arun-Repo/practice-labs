# Installing Argo CD

This guide covers a complete installation of Argo CD using Helm on a Kubernetes cluster, configured for local development and demonstration use.

---

## Prerequisites

- A running Kubernetes cluster (1.19+)
- `kubectl` configured with cluster access
- `helm` 3.x installed
- For NodePort access: a cluster node with an accessible IP or hostname

---

## Installation Steps

### 1. Create namespace

```bash
kubectl create namespace argocd
```

### 2. Add Argo CD Helm repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### 3. Install Argo CD using Helm

This command installs Argo CD with the UI exposed via NodePort on port 30090, suitable for demo and learning environments.

```bash
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=NodePort \
  --set server.service.nodePort=30090
```

Wait for all pods to be running:

```bash
kubectl get pods -n argocd -w
```

Press Ctrl+C when all pods show `Running` and `1/1` ready.

### 4. Get the initial admin password

```bash
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PASSWORD"
```

Save this password. You can retrieve it again at any time using the command above.

### 5. Access the Argo CD UI

Find your cluster node's external IP or hostname:

```bash
kubectl get nodes -o wide
```

Open in a browser (replace `<EC2-IP>` or `<NODE-IP>` with your actual node IP):

```
https://<NODE-IP>:30090
```

Login with:
- **Username:** `admin`
- **Password:** (from Step 4)

**Note:** The UI uses a self-signed certificate. Ignore the SSL warning in your browser.

### 6. Login with ArgoCD CLI

Install the `argocd` CLI if not already present:

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Or use your package manager
```

Login to the cluster:

```bash
argocd login <NODE-IP>:30090 --insecure \
  --username admin \
  --password $ARGOCD_PASSWORD
```

Verify authentication:

```bash
argocd version --short
argocd cluster info
argocd app list
```

### 7. Configure Git repository access

#### For public repositories

Argo CD can read public Git repositories without additional configuration. Just provide the public repository URL when creating Applications.

#### For private repositories

Add repository credentials to Argo CD:

```bash
argocd repo add https://github.com/<owner>/<repo>.git \
  --username <git-username> \
  --password <git-token>
```

For GitHub with SSH keys:

```bash
argocd repo add git@github.com:<owner>/<repo>.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

Verify the repository is accessible:

```bash
argocd repo list
```

---

## Post-Installation

### Change the admin password

For production or shared environments, change the default admin password:

```bash
argocd account update-password \
  --account admin \
  --current-password $ARGOCD_PASSWORD \
  --new-password <new-password>
```

### Create additional users

```bash
kubectl patch configmap argocd-cm -n argocd -p '{"data":{"accounts.myuser":"login"}}'
argocd account update-password --account myuser --new-password <password>
```

### Enable authn/authz integrations

For production deployments, integrate with external authentication providers (OIDC, OAuth2, LDAP, etc.). See [Argo CD documentation](https://argo-cd.readthedocs.io/) for advanced configuration.

### Expose via production ingress

For production use, replace NodePort with an Ingress controller and configure TLS:

```bash
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=nginx \
  --set server.ingress.hosts[0]=argocd.example.com \
  --set server.insecure=false \
  --set server.certificate.enabled=true
```

---

## Verification

Confirm the installation with these checks:

```bash
# Check all pods are running
kubectl get pods -n argocd

# Check Argo CD CRDs are installed
kubectl get crds | grep argoproj

# Verify the API is responding
argocd app list

# Check the default cluster is registered
kubectl get secret -n argocd | grep cluster
```

---

## Uninstall

If you need to remove Argo CD:

```bash
helm uninstall argocd --namespace argocd
kubectl delete namespace argocd
```

---

## Next Steps

- [Return to demo runbook](./argocd-demo-runbook.md)
- [Main Argo CD reference architectures](./README.md)
- [Official Argo CD documentation](https://argo-cd.readthedocs.io/)
