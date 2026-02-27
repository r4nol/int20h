#!/usr/bin/env bash
# bootstrap.sh — One-time setup after terraform apply
# Run this from your local machine, not from the VM
set -euo pipefail

VM_IP="${1:?Usage: $0 <VM_IP> <GITHUB_ORG>}"
GITHUB_ORG="${2:?Usage: $0 <VM_IP> <GITHUB_ORG>}"
SSH_USER="${3:-ubuntu}"

echo "==> Bootstrapping INT20H DevOps cluster"
echo "    VM: ${VM_IP}"
echo "    GitHub Org: ${GITHUB_ORG}"
echo ""

# Step 1: Replace placeholder GITHUB_ORG in all manifests
echo "==> [1/5] Replacing GITHUB_ORG placeholders..."
find . -name "*.yaml" -not -path "./_upstream/*" -not -path "./.git/*" | \
  xargs grep -l "GITHUB_ORG" | \
  while read -r file; do
    sed -i.bak "s/GITHUB_ORG/${GITHUB_ORG}/g" "$file"
    rm -f "${file}.bak"
    echo "    Updated: $file"
  done

# Step 2: Verify k3s is running on VM
echo "==> [2/5] Verifying k3s on VM ${VM_IP}..."
ssh "${SSH_USER}@${VM_IP}" kubectl get nodes

# Step 3: Copy ArgoCD root app to VM and apply
echo "==> [3/5] Bootstrapping ArgoCD root Application..."
scp argocd/root-app/root-application.yaml "${SSH_USER}@${VM_IP}:/tmp/root-application.yaml"
ssh "${SSH_USER}@${VM_IP}" kubectl apply -f /tmp/root-application.yaml

# Step 4: Wait for ArgoCD to sync
echo "==> [4/5] Waiting for ArgoCD to create child Applications (60s)..."
sleep 60
ssh "${SSH_USER}@${VM_IP}" kubectl get applications -n argocd

# Step 5: Get ArgoCD admin password
echo "==> [5/5] ArgoCD admin credentials:"
ARGOCD_PASSWORD=$(ssh "${SSH_USER}@${VM_IP}" \
  kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d)

echo ""
echo "==========================================="
echo " Bootstrap Complete!"
echo "==========================================="
echo ""
echo " Online Boutique (Production): http://${VM_IP}:30080"
echo " Online Boutique (Staging):    http://${VM_IP}:30180"
echo " ArgoCD UI:                    https://${VM_IP}:30443"
echo " Grafana:                      http://${VM_IP}:30300"
echo ""
echo " ArgoCD Login:"
echo "   Username: admin"
echo "   Password: ${ARGOCD_PASSWORD}"
echo ""
echo " Next steps:"
echo "   1. Add GitHub secret K8S_SERVER = https://${VM_IP}:6443"
echo "   2. Push a change to src/frontend/ to trigger first CI run"
echo "   3. Watch ArgoCD UI sync boutique-staging"
echo "   4. Open Grafana and verify dashboards have data"
