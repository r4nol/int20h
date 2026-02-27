#!/usr/bin/env bash
# install-argocd.sh — Install ArgoCD via Helm and expose it on NodePort 30443
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "==> [1/4] Adding ArgoCD Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "==> [2/4] Installing ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version "7.x" \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=30380 \
  --set server.service.nodePortHttps=30443 \
  --set server.insecure=false \
  --set configs.params."server\.insecure"=false \
  --set crds.install=true \
  --set redis.enabled=true \
  --set "server.resources.requests.cpu=100m" \
  --set "server.resources.requests.memory=128Mi" \
  --set "server.resources.limits.cpu=500m" \
  --set "server.resources.limits.memory=512Mi" \
  --wait \
  --timeout 10m

echo "==> [3/4] Waiting for ArgoCD to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=5m

echo "==> [4/4] Installing ArgoCD CLI..."
ARGOCD_VERSION=$(helm show chart argo/argo-cd | grep '^appVersion' | awk '{print $2}' | tr -d '"')
curl -sSL -o /usr/local/bin/argocd \
  "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64"
chmod +x /usr/local/bin/argocd

echo ""
echo "==========================================="
echo " ArgoCD installed!"
echo "==========================================="
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d)
echo " URL:      https://$(curl -s ifconfig.me):30443"
echo " Username: admin"
echo " Password: ${ARGOCD_PASSWORD}"
echo ""
echo " IMPORTANT: Change the default password after first login!"
echo " argocd account update-password"
echo ""
echo " The root Application will be applied by GitHub Actions or manually:"
echo " kubectl apply -f argocd/root-app/root-application.yaml"
