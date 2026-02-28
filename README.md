# INT20H 2026 — DevOps Track: Online Boutique on Oracle Cloud + k3s

> **Live Demo:** `https://int20h-production.r4nol.dev` | **ArgoCD:** `https://int20h-argocd.r4nol.dev` | **Grafana:** `https://int20h-grafana.r4nol.dev`

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────┐  │
│  │ src/frontend │  │src/cartservice│  │  k8s/ argocd/ monitoring/   │  │
│  └──────┬───────┘  └──────┬────────┘  └──────────────────────────────┘  │
│         │                 │                        │                     │
│         ▼                 ▼                        ▼                     │
│  ┌─────────────────────────────┐         ┌──────────────────┐           │
│  │   GitHub Actions CI/CD      │         │  ArgoCD (GitOps) │           │
│  │  Build → Scan → Push        │         │  Pull-based sync │           │
│  │  (Trivy, multi-arch)        │         │  App-of-Apps     │           │
│  └──────────────┬──────────────┘         └────────┬─────────┘           │
│                 │                                  │                     │
│                 ▼                                  │                     │
│  ┌──────────────────────────┐                      │                     │
│  │  GHCR (GitHub Container  │                      │                     │
│  │  Registry) — free        │                      │                     │
│  └──────────────────────────┘                      │                     │
└────────────────────────────────────────────────────┼────────────────────┘
                                                      │
                 ┌────────────────────────────────────▼───────────────────┐
                 │                Oracle Cloud VM (ARM64)                  │
                 │  ┌─────────────────────────────────────────────────┐   │
                 │  │                k3s Cluster                      │   │
                 │  │                                                 │   │
                 │  │  ┌──────────────────┐  ┌──────────────────┐    │   │
                 │  │  │  ns: staging     │  │  ns: production  │    │   │
                 │  │  │  11 microservices│  │  11 microservices│    │   │
                 │  │  │  replicas: 1     │  │  frontend: 2     │    │   │
                 │  │  │  NodePort: 30180 │  │  cart: 2 + HPA   │    │   │
                 │  │  │  NetworkPolicy   │  │  PDB, NP, HPA    │    │   │
                 │  │  └──────────────────┘  └──────────────────┘    │   │
                 │  │                                                 │   │
                 │  │  ┌──────────────────┐  ┌──────────────────┐    │   │
                 │  │  │  ns: argocd      │  │  ns: monitoring  │    │   │
                 │  │  │  ArgoCD Server   │  │  Prometheus      │    │   │
                 │  │  │  :30443          │  │  Grafana :30300  │    │   │
                 │  │  └──────────────────┘  └──────────────────┘    │   │
                 │  └─────────────────────────────────────────────────┘   │
                 │                                                         │
                 │  OCI Security List: 22, 6443, 30080, 30180, 30300, 30443│
                 └─────────────────────────────────────────────────────────┘
```

### CI/CD Flow Diagram

```
Push to main (any src/<service>/...)
         │
         ▼
  GitHub Actions CI
  ┌────────────────────────────────────┐
  │ 1. docker/metadata-action           │  → Tags: main-<sha>, latest
  │ 2. docker/build-push-action         │  → Multi-arch: amd64 + arm64
  │    (BuildKit cache: type=gha)       │  → SBOM provenance attestation
  │ 3. aquasecurity/trivy-action        │  → CRITICAL/HIGH scan, exit-code=1
  │ 4. github/codeql-action/upload-sarif│  → GitHub Security tab
  └────────────────┬───────────────────┘
                   │ (main branch only)
                   ▼
  GitHub Actions Deploy (shared)
  ┌────────────────────────────────────┐
  │ 5. kustomize edit set image         │  → Updates overlay kustomization.yaml
  │ 6. git commit + push                │  → GitOps: image tag in Git = source of truth
  │ 7. Poll ArgoCD Application status   │  → Wait Healthy+Synced (OIDC auth, no kubeconfig)
  └────────────────────────────────────┘
                   │
                   ▼
  ArgoCD detects new commit
  ┌────────────────────────────────────┐
  │ Staging: automated sync             │  → Immediate deployment
  │ Production: manual sync required    │  → workflow_dispatch or ArgoCD UI click
  └────────────────────────────────────┘
```

---

## Technology Decisions

| Concern | Choice | Alternative Considered | Justification |
|---------|--------|----------------------|---------------|
| K8s distribution | **k3s** | kubeadm, minikube | ARM64 native, <512MB RAM, single binary, Oracle Free Tier compatible |
| Cloud | **Oracle Cloud** | GCP, AWS, Azure | Existing VM, ARM64 Always Free (4 OCPUs, 24GB RAM), zero cost |
| Container Registry | **GHCR** | DockerHub, ECR | Free, integrated with GitHub Actions GITHUB_TOKEN, no extra auth setup |
| GitOps | **ArgoCD** | Flux CD | Better UI for demos, App-of-Apps pattern, ArgoCD Notifications |
| IaC | **Terraform + OCI** | Pulumi, Ansible | Mature OCI provider, declarative, state management |
| CI Authentication | **OIDC** | kubeconfig Secret | Ephemeral 10-min tokens, no credential rotation, cryptographically bound to repo |
| Monitoring | **Prometheus + Grafana** | Datadog, New Relic | OSS, Helm operator, Kubernetes-native, k3s-compatible |
| Env management | **Kustomize** | Helm, plain YAML | No templating overhead, pure YAML overlays, `kustomize edit set image` for CI |
| Deploy pattern | **GitOps commit** | `kubectl set image` | Full audit trail, rollback = git revert, ArgoCD drift detection works |

---

## Quick Start

### Prerequisites

- Oracle Cloud VM (Ubuntu 22.04, ARM64)
- Terraform >= 1.6.0
- GitHub repository with Actions enabled
- `kubectl`, `kustomize` 5.x installed locally

### 1. Fork and Clone

```bash
git clone https://github.com/r4nol/int20h
cd int20h
```

### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your OCI credentials and VM IP
vim terraform.tfvars
```

Required values:
```hcl
vm_public_ip = "YOUR_ORACLE_VM_IP"
github_repo  = "YOUR_GITHUB_ORG/int20h"
ssh_private_key = "-----BEGIN OPENSSH PRIVATE KEY-----\n..."
# ... see terraform.tfvars.example for all fields
```

### 3. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

This will:
- ✅ Create OCI Security List (open required ports)
- ✅ Install k3s on the VM with OIDC flags
- ✅ Install ArgoCD via Helm
- ✅ Create namespaces: staging, production, argocd, monitoring
- ✅ Configure RBAC for GitHub Actions OIDC auth

**Expected output:**
```
frontend_production_url = "https://int20h-production.<your-domain>"
frontend_staging_url    = "https://int20h-staging.<your-domain>"
argocd_url             = "https://int20h-argocd.<your-domain>"
grafana_url            = "https://int20h-grafana.<your-domain>"
```

### 4. Configure GitHub Actions Secrets

In your GitHub repository → Settings → Secrets → Actions:

| Secret | Value | Description |
|--------|-------|-------------|
| `K8S_SERVER` | `https://VM_IP:6443` | k3s API server (not a kubeconfig!) |

Configure GitHub Environments (Settings → Environments):
- `staging` — no protection rules (auto-deploy)
- `production` — add Required Reviewers for manual gate

### 5. Bootstrap ArgoCD

```bash
# Replace GITHUB_ORG in root-application.yaml first
sed -i 's/GITHUB_ORG/your-org/g' argocd/root-app/root-application.yaml
sed -i 's/GITHUB_ORG/your-org/g' argocd/apps/*.yaml

# Apply the root App-of-Apps
ssh ubuntu@VM_IP kubectl apply -f /path/to/argocd/root-app/root-application.yaml
```

### 6. Configure Domain Hosts For TLS

Set real FQDNs used in Cloudflare A records:

```bash
vim edge/gateways/hosts.env
```

Example:

```env
LETSENCRYPT_EMAIL=you@example.com
ARGOCD_HOST=int20h-argocd.example.com
GRAFANA_HOST=int20h-grafana.example.com
STAGING_HOST=int20h-staging.example.com
PRODUCTION_HOST=int20h-production.example.com
```

Then push to `main`. ArgoCD will deploy:
- `ingress-nginx` (entrypoint on :80/:443)
- `cert-manager` (Let's Encrypt)
- ingress gateways with auto-issued TLS certs

Cloudflare requirements:
- A records for all four hosts must point to VM public IP
- Keep ports `80` and `443` open on OCI Security List + VM iptables
- SSL/TLS mode: `Full (strict)` after first cert issuance
- If ACME HTTP-01 challenge fails while records are proxied, temporarily switch records to `DNS only`, wait for certs to become `Ready`, then enable proxy again

ArgoCD will automatically create and sync all child Applications.

### 6. Get ArgoCD Admin Password

```bash
ssh ubuntu@VM_IP \
  kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

### 7. Update GITHUB_ORG Placeholders

```bash
# Replace all GITHUB_ORG placeholders with your actual org/username
find . -name "*.yaml" -o -name "*.json" | \
  xargs sed -i 's/GITHUB_ORG/your-actual-org/g'
git commit -am "chore: configure GitHub org"
git push
```

---

## CI/CD Pipeline

### Automated (on push to `main`)

1. Push code change to `src/<service>/` (for any of 11 services)
   - Build context expects `src/<service>/Dockerfile` (or `src/<service>/src/Dockerfile` for cartservice layout)
2. GitHub Actions (`ci-microservices.yaml`) detects changed services and runs CI per service
3. Docker image is built (multi-arch: amd64 + arm64)
4. Trivy scans for CRITICAL/HIGH vulnerabilities
5. Image is pushed to `ghcr.io/ORG/SERVICE:main-<sha>`
6. `deploy.yaml` updates `k8s/overlays/staging/kustomization.yaml` via `kustomize edit set image`
7. Git commit is pushed: `chore(deploy): <service> → main-abc1234 in staging`
8. ArgoCD detects the commit and syncs staging namespace automatically
9. Deploy workflow polls ArgoCD status via OIDC until `Healthy+Synced`

### Manual Production Promotion

```
GitHub → Actions → Deploy (shared) → Run workflow
  Service: frontend
  Image tag: main-abc1234  (copy from staging deploy)
  Environment: production
→ Requires reviewer approval (GitHub Environment protection)
→ ArgoCD sync must be triggered manually in UI or via argocd CLI
```

Or via ArgoCD UI: click `Sync` on `boutique-production` Application.

---

## Monitoring & Dashboards

Open Grafana at `https://int20h-grafana.r4nol.dev` (anonymous read-only access).

### Dashboard 1: RED Method

> **Online Boutique — RED Method**

Surfaces Rate, Errors, and Duration per microservice across both environments:

- **Rate**: Requests/sec per service, staging vs production
- **Errors**: Error rate (5xx/total), color-coded: >1% yellow, >5% red
- **Duration**: P50/P95/P99 latency percentiles
- **Frontend deep-dive**: Status code breakdown, P99 vs SLO (500ms), staging vs prod comparison

### Dashboard 2: SLO Error Budget

> **Online Boutique — SLO Error Budget**

Implements Google SRE Book Chapter 5 multi-window burn rate methodology:

- **SLO**: 99.9% availability (43.8 min/month error budget)
- **1h burn rate**: >14x = fast burn → immediate page
- **6h burn rate**: >2x = slow burn → ticket
- **Latency SLO**: P99 < 500ms compliance per service
- Error budget remaining visualization with minutes-to-breach

### Dashboard 3: K8s Resources

> **Online Boutique — K8s Resources**

Kubernetes resource utilization and stability:

- **Node health**: CPU/Memory/Disk gauges (critical on single-node)
- **CPU/Memory by namespace**: staging, production, monitoring, argocd
- **HPA scaling**: Current/min/max replicas, capacity utilization
- **Pod restarts**: Canary metric for stability (>5/hour = red)
- **Pod phases**: Running/Pending/Failed by namespace

---

## Security Architecture

### Authentication: GitHub Actions OIDC

No long-lived credentials are stored anywhere. GitHub Actions requests an ephemeral OIDC JWT (valid 10 minutes) from GitHub's token endpoint. The JWT is used to authenticate directly to the k3s API server.

```
GitHub Actions Runner
       │
       │ 1. Request OIDC token (audience: my-k3s-cluster)
       ▼
GitHub Token Service
       │
       │ 2. Returns JWT (sub: repo:ORG/REPO:ref:refs/heads/main)
       ▼
k3s API Server
       │
       │ 3. Validates JWT against https://token.actions.githubusercontent.com
       │    Checks oidc-required-claim=repository=ORG/REPO (rejects other repos)
       ▼
       │ 4. Returns ClusterRole permissions (read-only: pods, deployments, applications)
```

**k3s API server OIDC flags:**
```
--oidc-issuer-url=https://token.actions.githubusercontent.com
--oidc-client-id=my-k3s-cluster
--oidc-required-claim=repository=ORG/REPO   ← Restricts to your repo only
```

### Network Policies

**Production namespace**: Zero-trust with service-level microsegmentation:
- Default deny all ingress
- Frontend: allow all (entry point)
- cartservice: only from frontend + checkoutservice
- redis-cart: only from cartservice
- Prometheus scraping: only from monitoring namespace

**Staging namespace**: Allow intra-namespace + monitoring scraping (relaxed for debugging).

### Container Security

- All upstream manifests use `runAsNonRoot: true`, `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`
- Trivy scans every build for CRITICAL/HIGH CVEs (exits 1 on finding)
- SBOM provenance attestations via `docker/build-push-action provenance: true`

---

## Runbook

### Rolling Back a Deployment

```bash
# Option 1: Git revert (preferred — maintains audit trail)
git log --oneline k8s/overlays/production/kustomization.yaml
git revert <commit-sha>
git push
# Then manually sync in ArgoCD UI

# Option 2: ArgoCD rollback via CLI
argocd app rollback boutique-production <revision-number>
```

### Scaling Services Manually

```bash
# Temporary scale (HPA will adjust back based on CPU)
kubectl scale deployment frontend -n production --replicas=3

# Permanent: edit k8s/overlays/production/patches/replicas.yaml, commit, ArgoCD syncs
```

### Accessing Logs

```bash
# Frontend logs
kubectl logs -n production -l app=frontend --tail=100 -f

# All services in production
kubectl logs -n production --selector=app.kubernetes.io/part-of=online-boutique --tail=50
```

### Destroying Infrastructure

```bash
cd terraform
terraform destroy
# Note: existing Oracle VM is referenced via data source and will NOT be deleted
# Only security lists and k3s bootstrap resources are destroyed
```

---

## Repository Structure

```
int20h/
├── .github/workflows/
│   ├── ci-microservices.yaml   # Detect changed src/<service>, Build → Trivy → Push → Deploy staging
│   └── deploy.yaml             # Shared: kustomize update + ArgoCD verify
├── terraform/
│   ├── main.tf                 # OCI provider + module calls (data source for existing VM)
│   ├── variables.tf / outputs.tf / versions.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── oci-security/       # OCI Security List (firewall rules)
│       └── k3s-bootstrap/      # k3s + ArgoCD installation via SSH remote-exec
│           └── scripts/
│               ├── install-k3s.sh      # k3s with OIDC API flags
│               └── install-argocd.sh   # ArgoCD Helm + CLI
├── k8s/
│   ├── base/                   # Upstream microservices-demo YAMLs (pinned v0.10.2)
│   └── overlays/
│       ├── staging/            # 1 replica, reduced resources, NodePort 30180
│       └── production/         # 2 replicas, HPA, PDB, NetworkPolicy, NodePort 30080
├── argocd/
│   ├── root-app/               # App-of-Apps bootstrap (single kubectl apply)
│   ├── projects/               # AppProject per environment (source/dest restrictions)
│   └── apps/                   # Child Applications (staging, production, monitoring, ingress, cert-manager)
├── edge/
│   └── gateways/               # Ingress + ClusterIssuer + host config (auto TLS)
├── monitoring/
│   ├── helm/                   # kube-prometheus-stack Helm values (k3s-tuned)
│   ├── dashboards/             # 3 Grafana dashboard JSONs
│   └── kustomization.yaml      # ConfigMapGenerator for dashboard injection
├── src/
│   ├── frontend/               # Source + Dockerfile (editable)
│   ├── cartservice/            # Source + Dockerfile in src/
│   └── ... 9 more services     # Full upstream service sources (v0.10.0)
└── README.md
```

---

## Hackathon Scoring Checklist

| Requirement | Status | Details |
|-------------|--------|---------|
| Terraform піднімає/зносить інфраструктуру | ✅ | OCI Security Lists + k3s bootstrap via remote-exec |
| Staging + Prod (K8S namespaces) з доступним frontend | ✅ | staging:30180, production:30080, NetworkPolicies |
| CI/CD для 11 сервісів (build+push+deploy) | ✅ | Будь-який `src/<service>` із Dockerfile, GitHub Actions, GHCR |
| 2-3 корисних дашборди (reliability/scalability) | ✅ | RED Method + SLO Error Budget + K8s Resources |
| README з скріншотами | ✅ | See `docs/screenshots/` after deployment |
| Високорівневий опис cloud-архітектури | ✅ | Architecture diagram above |
| Відео з end-to-end workflow | 📹 | Record after deployment (see docs/video-script.md) |
| **Bonus:** GitOps (ArgoCD) | ✅ | App-of-Apps, automated staging, manual production |
| **Bonus:** OIDC (no long-lived secrets) | ✅ | Ephemeral JWT tokens, zero static credentials |
| **Bonus:** Vulnerability scanning | ✅ | Trivy CRITICAL/HIGH, SARIF → GitHub Security tab |
| **Bonus:** HPA + PDB (production) | ✅ | autoscaling/v2 with behavior, minAvailable: 1 |
| **Bonus:** NetworkPolicies | ✅ | Zero-trust production, default-deny-ingress |
| **Bonus:** Multi-arch images | ✅ | linux/amd64 + linux/arm64 |
| **Bonus:** SLO Error Budget dashboard | ✅ | Multi-window burn rate (Google SRE methodology) |

---

*Built for INT20H 2026 Hackathon - DevOps Track*
