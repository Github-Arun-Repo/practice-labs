# ArgoCD Live Demo — 1 Hour Runbook

**Repo:** `https://github.com/Github-Arun-Repo/platform-engineering-reference-architectures.git`
**Base folder:** `.` (current directory in argocd-reference-architectures/)
**Cluster:** standalone K8s on EC2 · **ArgoCD UI:** `https://<EC2-IP>:30090`
**Presenter:** Arun

---

## Repo layout (all paths below match this)

```
cli-demo/
├── argocd/                     # pre-written Application manifests
│   │   ├── nginx-demo-app.yaml     # nginx-demo      → k8s/nginx-demo     (NodePort 30095)
│   │   ├── httpd-demo-app.yaml     # httpd-demo      → k8s/httpd-demo     (ClusterIP)
│   │   ├── whoami-demo-app.yaml    # whoami-demo     → k8s/whoami-demo    (NodePort 30096)
│   │   └── logstorm-demo-app.yaml  # logstorm-demo   → k8s/logstorm-demo  (log generator, no svc)
│   └── k8s/                        # raw manifests for each app
├── app-of-apps-demo/
│   ├── argocd/
│   │   ├── app-of-apps-parent.yaml           # argo-demo-parent → children/
│   │   └── children/                         # 3 child Application YAMLs + kustomization.yaml
│   │       ├── alpha-nginx-app.yaml          # aoa-alpha-nginx
│   │       ├── beta-httpd-app.yaml           # aoa-beta-httpd
│   │       ├── gamma-whoami-app.yaml         # aoa-gamma-whoami
│   │       └── kustomization.yaml
│   └── k8s/{alpha-nginx,beta-httpd,gamma-whoami}/   # ClusterIP services
└── applicationset-demo/
    ├── argocd/applicationset-demo.yaml       # list generator → aset-nginx, aset-httpd, aset-whoami
    └── k8s/{aset-nginx,aset-httpd,aset-whoami}/     # ClusterIP services
```

---

## Installation: Deploy Argo CD

Follow the complete installation and setup guide: **[installation-argocd.md](./installation-argocd.md)**

That document covers:
- Helm installation steps
- CLI authentication
- Repository access configuration
- Post-installation setup
- Production considerations

After completing the installation, return here to continue with the demo.

---

## 0. PRE-FLIGHT

Run these checks before starting the demo. Assume Argo CD is already installed from the Installation section above.

```bash
# local clone current?
cd ~/platform-engineering-reference-architectures && git pull        # adjust to your local clone path

# ArgoCD healthy + logged in
kubectl get pods -n argocd            # all Running
argocd login <EC2-IP>:30090 --insecure
argocd version --short
argocd app list                       # see what's already there

# CLEAN SLATE so the demo starts from zero
argocd app delete nginx-demo httpd-demo whoami-demo logstorm-demo --yes 2>/dev/null || true
argocd app delete argo-demo-parent aoa-alpha-nginx aoa-beta-httpd aoa-gamma-whoami --yes 2>/dev/null || true
kubectl delete applicationset applicationset-demo -n argocd 2>/dev/null || true
kubectl delete ns nginx-demo httpd-demo whoami-demo logstorm-demo \
  aoa-alpha-nginx aoa-beta-httpd aoa-gamma-whoami \
  aset-nginx aset-httpd aset-whoami 2>/dev/null || true

echo "Ready."
```

**Timing plan:**
- Installation (one-time): ≈ 10 min
- Pre-flight checks: ≈ 2 min
- CLI demo: ≈ 28 min
- App-of-Apps demo: ≈ 15 min
- ApplicationSet demo: ≈ 12 min
- Q&A: ≈ 5 min
- **Total demo time (without installation): ≈ 60 min**

---
---

# PART 1 — ArgoCD via the CLI  (≈28 min)

> Goal: everyone leaves fluent in the day-to-day `argocd` commands and the core mental model.

## 1.1 — Create an app & watch the OutOfSync → Synced flow

**Say:** "An Application binds a Git source to a cluster destination. Let's create one but NOT auto-sync, so we can see the states."

```bash
argocd app create nginx-demo \
  --repo https://github.com/Github-Arun-Repo/platform-engineering-reference-architectures.git \
  --path argocd-reference-architectures/cli-demo/k8s/nginx-demo \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace nginx-demo \
  --sync-option CreateNamespace=true \
  --sync-policy none

argocd app get nginx-demo
```
👉 `Sync Status: OutOfSync` · `Health: Missing` — declared in Git, not yet on the cluster.

```bash
argocd app sync nginx-demo
argocd app get nginx-demo
kubectl get all -n nginx-demo
curl -s http://localhost:30095 | grep -i title
```
👉 Now `Synced` / `Healthy`. The nginx welcome page proves it's live on NodePort 30095.

## 1.2 — Create from an existing manifest file (declarative create)

**Say:** "In real life you don't type `argocd app create` — you commit an Application YAML. Same result."

```bash
# your repo already has the Application manifest — just apply it
kubectl apply -f cli-demo/argocd/whoami-demo-app.yaml
argocd app list
argocd app get whoami-demo
curl -s http://localhost:30096 | head -15
```
👉 `whoami-demo` shows each request's pod/hostname — handy to show load-balancing across its 2 replicas.

## 1.2A — One more app using ArgoCD CLI (imperative)

**Say:** "Let me create a second app entirely from `argocd` CLI so you can compare imperative vs declarative styles side-by-side."

```bash
argocd app create httpd-demo \
  --repo https://github.com/Github-Arun-Repo/platform-engineering-reference-architectures.git \
  --path argocd-reference-architectures/cli-demo/k8s/httpd-demo \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace httpd-demo \
  --sync-option CreateNamespace=true \
  --sync-policy manual

argocd app get httpd-demo
argocd app sync httpd-demo
kubectl get all -n httpd-demo
```

👉 This app is now fully managed by Argo CD even though no Application YAML was applied from Git.

Optional check (ClusterIP app):

```bash
kubectl port-forward -n httpd-demo svc/httpd-demo 8081:80
curl -s http://localhost:8081 | head -20
```

## 1.3 — Inspect: get, diff, manifests, resource tree, raw CR

**Say:** "The commands you'll actually live in for troubleshooting."

```bash
argocd app get nginx-demo                       # summary + resource tree
argocd app manifests nginx-demo | head -30      # exactly what ArgoCD will apply
argocd app resources nginx-demo                 # list owned resources
kubectl get application nginx-demo -n argocd -o yaml | head -40   # the raw CR

# make a live change and DIFF it against Git
kubectl -n nginx-demo set image deploy/nginx-demo nginx=nginx:1.25-alpine
argocd app diff nginx-demo                       # shows the drift as a diff
```
👉 `argocd app diff` prints a red/green diff of live-vs-Git. Great for "what changed?"

## 1.4 — Drift detection (manual policy) then manual re-sync

```bash
# nginx-demo is still on manual sync-policy
kubectl scale deploy/nginx-demo -n nginx-demo --replicas=5
argocd app get nginx-demo
```
👉 `OutOfSync` — ArgoCD SEES the drift (5 vs 3) but does nothing yet.

```bash
argocd app sync nginx-demo         # manual reconcile back to Git
kubectl get deploy nginx-demo -n nginx-demo
```
👉 Back to 3 replicas. "Manual policy = ArgoCD reports drift but waits for a human."

## 1.5 — Self-heal (automated drift correction)

```bash
argocd app set nginx-demo --sync-policy automated --self-heal
kubectl scale deploy/nginx-demo -n nginx-demo --replicas=5
sleep 8
kubectl get deploy nginx-demo -n nginx-demo
```
👉 Snaps back to 3 on its own, no command. "Self-heal enforces Git against cluster-side tampering."

## 1.6 — Automated sync from a Git commit

**Say:** "With automated sync, a Git push IS the deploy."

```bash
sed -i 's/replicas: 3/replicas: 4/' cli-demo/k8s/nginx-demo/deployment.yaml
git add -A && git commit -m "nginx to 4 replicas (demo)" && git push

argocd app get nginx-demo --refresh    # force immediate compare (skip 3-min poll)
sleep 5
kubectl get pods -n nginx-demo
```
👉 4 pods, triggered purely by the commit.

## 1.7 — Prune (deleting from Git removes from cluster)

**Say:** "Automated sync alone won't DELETE. You must opt into prune."

```bash
argocd app set nginx-demo --sync-policy automated --self-heal --auto-prune
# remove the Service from Git
git rm cli-demo/k8s/nginx-demo/service.yaml
git commit -m "remove nginx service (demo prune)" && git push
argocd app get nginx-demo --refresh
sleep 6
kubectl get svc -n nginx-demo
```
👉 The Service is gone from the cluster — prune removed the orphan. Restore it:
```bash
git revert --no-edit HEAD && git push
argocd app get nginx-demo --refresh
```

## 1.8 — Sync = applied, Health = working (break on purpose)

**Say:** "Critical distinction: a manifest can apply cleanly yet the app be broken."

```bash
sed -i 's#image: nginx:1.27-alpine#image: nginx:does-not-exist#' cli-demo/k8s/nginx-demo/deployment.yaml
git add -A && git commit -m "bad image (demo)" && git push
argocd app get nginx-demo --refresh
sleep 8
kubectl get pods -n nginx-demo
```
👉 `Sync: Synced` (manifest applied) but `Health: Degraded` — pods in `ImagePullBackOff`.

## 1.9 — History & rollback + the git-revert nuance

```bash
argocd app history nginx-demo
argocd app rollback nginx-demo <GOOD_ID>    # pick the last healthy revision id
kubectl get pods -n nginx-demo
```
👉 Cluster recovers. **But** Git still has the bad commit; with automated sync it may drift forward.
The correct fix is fixing Git:
```bash
git revert --no-edit HEAD && git push
argocd app get nginx-demo --refresh
```
👉 "Rollback = emergency brake. `git revert` = the real fix. Git stays the source of truth."

## 1.10 — Logstorm app: workloads that aren't web servers

**Say:** "Not everything is a web server — here's a noisy log generator, ties into observability talk."

```bash
kubectl apply -f cli-demo/argocd/logstorm-demo-app.yaml
argocd app get logstorm-demo
kubectl logs -n logstorm-demo -l app=logstorm-demo --tail=5 --prefix
```
👉 Streams demo log lines — good bridge if anyone asks about Graylog/Fluent Bit integration.

## 1.11 — Housekeeping commands

```bash
argocd app list -o wide
argocd app set nginx-demo --sync-policy none      # turn automation back off
argocd app get nginx-demo -o json | jq '.status.sync.status,.status.health.status'
argocd app delete httpd-demo --yes                # (if created) clean removal
```

**PART 1 wrap-up line:** "That's the whole CLI surface: create, sync, diff, drift, self-heal, prune, history, rollback. Now — how do we manage MANY apps at once?"

---
---

# PART 2 — App of Apps  (≈15 min)

> Goal: show one parent Application that declares many child Applications.

## 2.1 — The concept before the command

**Say:** "App of Apps is just an Application whose Git path contains OTHER Application manifests. No special CRD."

```bash
cat app-of-apps-demo/argocd/app-of-apps-parent.yaml
ls app-of-apps-demo/argocd/children/
```
👉 Parent `argo-demo-parent` points at `children/`, which holds 3 Application YAMLs + a kustomization.

## 2.2 — Deploy the parent, watch children appear

```bash
kubectl apply -f app-of-apps-demo/argocd/app-of-apps-parent.yaml
argocd app sync argo-demo-parent
argocd app list
```
👉 Without any per-app `create`, you now have `aoa-alpha-nginx`, `aoa-beta-httpd`, `aoa-gamma-whoami`.
The parent synced the child Application objects; each child then synced its own workloads.

## 2.3 — Visualize the tree in the UI

**Say:** "This is where the UI shines — open `argo-demo-parent`."
👉 In the UI the parent shows the 3 child Applications as its resources; drill into one to see its pods/services. Very intuitive for the team.

```bash
# same info via CLI
argocd app get argo-demo-parent
kubectl get pods -n aoa-alpha-nginx
kubectl get pods -n aoa-beta-httpd
kubectl get pods -n aoa-gamma-whoami
```

## 2.4 — Cascade sync & self-heal down the tree

```bash
# drift a child's workload directly
kubectl scale deploy -n aoa-alpha-nginx --all --replicas=5
argocd app get aoa-alpha-nginx
```
👉 The child (self-heal on) reverts it. The parent's health is a rollup of the children.

## 2.5 — Add a 4th child = one new file (the App-of-Apps cost)

**Say:** "To add an app here, you hand-write a new child Application and commit. Remember this effort — ApplicationSet removes it."

```bash
# copy an existing child as a template for a 4th (reuses alpha-nginx manifests so it deploys)
cp app-of-apps-demo/argocd/children/alpha-nginx-app.yaml \
   app-of-apps-demo/argocd/children/delta-extra-app.yaml
sed -i 's/aoa-alpha-nginx/aoa-delta-extra/g' \
   app-of-apps-demo/argocd/children/delta-extra-app.yaml
# register it in the kustomization
sed -i '/gamma-whoami-app.yaml/a\  - delta-extra-app.yaml' \
   app-of-apps-demo/argocd/children/kustomization.yaml

git add -A && git commit -m "app-of-apps: add 4th child (demo)" && git push
argocd app sync argo-demo-parent
argocd app list | grep aoa-
```
👉 A 4th child appears — but note you had to author a whole new file. "One file per app. Hold that thought."

## 2.6 — Cascade delete awareness (talk, optional to run)

**Say:** "Deleting the parent with cascade removes all children and their workloads."
```bash
# DEMO-ONLY awareness; skip unless showing teardown:
# argocd app delete argo-demo-parent --cascade --yes
```

**PART 2 wrap-up line:** "App of Apps is great for a small curated set. But every new app = a new file. Enter ApplicationSet."

---
---

# PART 3 — ApplicationSet  (≈12 min)

> Goal: one template + a generator that stamps out many Applications automatically.

## 3.1 — The definition

**Say:** "ApplicationSet is a separate CRD with its own controller. One template, a generator supplies the values."

```bash
cat applicationset-demo/argocd/applicationset-demo.yaml
```
👉 Point out: `generators.list.elements` (the 3 apps) and `template` with `{{appName}}`, `{{namespace}}`, `{{path}}`.

## 3.2 — Apply it, watch 3 apps generate at once

```bash
# ApplicationSet is applied with kubectl, NOT `argocd app create`
kubectl apply -f applicationset-demo/argocd/applicationset-demo.yaml
kubectl get applicationset -n argocd
argocd app list | grep aset-
```
👉 `aset-nginx`, `aset-httpd`, `aset-whoami` all appear — generated, none hand-created.

```bash
kubectl get pods -n aset-nginx
kubectl get pods -n aset-httpd
kubectl get pods -n aset-whoami
```

## 3.3 — THE money moment: add a 4th app with a 3-line edit

**Say:** "Compare to Part 2. There I wrote a whole file. Here I add 3 lines to a list."

```bash
# reuse an existing k8s path so it deploys immediately (aset-nginx manifests)
cat > /tmp/aset_patch.txt << 'EOF'
          - appName: aset-extra
            namespace: aset-extra
            path: applicationset-demo/k8s/aset-nginx
EOF
sed -i '/elements:/r /tmp/aset_patch.txt' \
  applicationset-demo/argocd/applicationset-demo.yaml

cat applicationset-demo/argocd/applicationset-demo.yaml   # verify
git add -A && git commit -m "appset: add 4th app (demo)" && git push
kubectl apply -f applicationset-demo/argocd/applicationset-demo.yaml

sleep 5
argocd app list | grep aset-
kubectl get ns | grep aset-extra
```
👉 `aset-extra` Application + namespace appear from a 3-line list entry. "That's the scaling difference."

## 3.4 — Self-heal works per generated app

```bash
kubectl scale deploy -n aset-nginx --all --replicas=6
sleep 8
kubectl get deploy -n aset-nginx
```
👉 Generated apps carry the template's `selfHeal`, so drift reverts automatically.

## 3.5 — Delete one element = its app is pruned

**Say:** "Remove an element from the list and its Application (and workloads) go away."

```bash
# remove the aset-extra element we just added
sed -i '/appName: aset-extra/,+2d' \
  applicationset-demo/argocd/applicationset-demo.yaml
git add -A && git commit -m "appset: remove 4th app (demo)" && git push
kubectl apply -f applicationset-demo/argocd/applicationset-demo.yaml
sleep 5
argocd app list | grep aset-       # aset-extra is gone
```
👉 The generator is the source of truth for WHICH apps exist. Drop an element → its app is removed.

## 3.6 — The powerful generators (talk, don't run)

**Say:** "The list generator is the simplest. In production you'd use:"
- **Git directory generator** — one app per folder; add a folder, an app appears (zero list editing).
- **Cluster generator** — one app per registered cluster; the multi-market / multi-region pattern.
- **Matrix generator** — cross-product, e.g. every app × every cluster.

"That's how a single ApplicationSet fans one workload across many environments or clusters."

**PART 3 wrap-up line:** "App of Apps = a file per app, best for a curated few. ApplicationSet = a list/generator, best for many similar apps across envs and clusters."

---
---

## RESET (after demo / to rehearse again)

```bash
# ApplicationSet
kubectl delete -f applicationset-demo/argocd/applicationset-demo.yaml 2>/dev/null || true
# App of Apps (cascade removes children)
argocd app delete argo-demo-parent --cascade --yes 2>/dev/null || true
# CLI apps
argocd app delete nginx-demo httpd-demo whoami-demo logstorm-demo --yes 2>/dev/null || true
# namespaces
kubectl delete ns nginx-demo httpd-demo whoami-demo logstorm-demo \
  aoa-alpha-nginx aoa-beta-httpd aoa-gamma-whoami aoa-delta-extra \
  aset-nginx aset-httpd aset-whoami aset-extra 2>/dev/null || true
# revert demo edits to Git
git checkout cli-demo/k8s/nginx-demo/deployment.yaml
git checkout cli-demo/k8s/nginx-demo/service.yaml 2>/dev/null || true
# (optional) drop the demo-added files:
# git rm app-of-apps-demo/argocd/children/delta-extra-app.yaml
# git checkout app-of-apps-demo/argocd/children/kustomization.yaml
# git checkout applicationset-demo/argocd/applicationset-demo.yaml
# git commit -m "reset demo state" && git push
```

---

## Command Cheat-Sheet (keep on screen during Q&A)

| Intent | Command |
|---|---|
| Create app (imperative) | `argocd app create <n> --repo <url> --path <p> --dest-namespace <ns> --dest-server https://kubernetes.default.svc` |
| Create app (declarative) | `kubectl apply -f <application>.yaml` |
| List apps | `argocd app list` (`-o wide` / `-o json`) |
| Status + tree | `argocd app get <n>` |
| Force recompare vs Git | `argocd app get <n> --refresh` |
| Show rendered manifests | `argocd app manifests <n>` |
| Diff live vs Git | `argocd app diff <n>` |
| Manual sync | `argocd app sync <n>` |
| Sync + delete removed | `argocd app sync <n> --prune` |
| Automate + self-heal + prune | `argocd app set <n> --sync-policy automated --self-heal --auto-prune` |
| Back to manual | `argocd app set <n> --sync-policy none` |
| History | `argocd app history <n>` |
| Rollback cluster | `argocd app rollback <n> <id>` |
| Delete (cascade) | `argocd app delete <n> --cascade --yes` |
| Raw CR | `kubectl get application <n> -n argocd -o yaml` |
| ApplicationSets | `kubectl get applicationset -n argocd` |

**Golden rules to repeat all hour:**
1. Git is the source of truth.
2. **Sync ≠ Health** (applied vs actually working).
3. `rollback` fixes the cluster; **`git revert` fixes the truth.**
4. App of Apps = a file per app · ApplicationSet = a list/generator per many apps.