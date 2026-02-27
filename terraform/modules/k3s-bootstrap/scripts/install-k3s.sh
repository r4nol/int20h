#!/usr/bin/env bash
# install-k3s.sh — Install k3s with OIDC API flags for GitHub Actions authentication
# Usage: sudo ./install-k3s.sh <k3s_version> <github_repo>
# Example: sudo ./install-k3s.sh v1.30.0+k3s1 myorg/int20h
set -euo pipefail

K3S_VERSION="${1:?Usage: $0 <k3s_version> <github_repo>}"
GITHUB_REPO="${2:?Usage: $0 <k3s_version> <github_repo>}"

echo "==> [1/6] Installing system dependencies + fixing Oracle Cloud firewall..."
apt-get update -qq
apt-get install -y -qq curl jq git iptables-persistent netfilter-persistent

# Oracle Cloud VMs have a local iptables that blocks NodePorts by default.
# OCI Security Lists control external firewall, but local iptables also needs opening.
echo "    Opening required ports in local iptables..."
for port in 22 80 443 6443 30080 30180 30300 30443; do
  iptables -C INPUT -p tcp --dport "${port}" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport "${port}" -j ACCEPT
done
netfilter-persistent save
echo "    iptables rules saved."

echo "==> [2/6] Installing k3s ${K3S_VERSION}..."
# Key flags explained:
#   --oidc-issuer-url        : Trust GitHub Actions JWT tokens (OIDC issuer)
#   --oidc-client-id         : Audience claim expected in the JWT
#   --oidc-username-claim    : Use 'sub' field as username (format: repo:ORG/REPO:ref:refs/heads/main)
#   --oidc-username-prefix   : Prefix to namespace OIDC users from SA users
#   --oidc-required-claim    : Reject tokens from other repos (security!)
#   --disable=traefik        : We use NodePort directly, no ingress controller needed
#   --write-kubeconfig-mode  : Allow non-root to read kubeconfig
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${K3S_VERSION}" \
  sh -s - server \
    --kube-apiserver-arg="oidc-issuer-url=https://token.actions.githubusercontent.com" \
    --kube-apiserver-arg="oidc-client-id=my-k3s-cluster" \
    --kube-apiserver-arg="oidc-username-claim=sub" \
    --kube-apiserver-arg="oidc-username-prefix=actions-oidc:" \
    --kube-apiserver-arg="oidc-required-claim=repository=${GITHUB_REPO}" \
    --kube-apiserver-arg="oidc-groups-claim=repository_owner" \
    --disable=traefik \
    --write-kubeconfig-mode=644 \
    --node-name=k3s-master

echo "==> [3/6] Waiting for k3s node to be Ready..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for i in $(seq 1 24); do
  if kubectl get nodes 2>/dev/null | grep -q " Ready"; then
    echo "    Node is Ready after ${i}x5s waits."
    break
  fi
  echo "    Waiting... (${i}/24)"
  sleep 5
done

kubectl get nodes

echo "==> [4/6] Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version --short

echo "==> [5/6] Creating namespaces..."
kubectl create namespace staging    --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd     --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Label namespaces for NetworkPolicy selectors
kubectl label namespace staging    kubernetes.io/metadata.name=staging    --overwrite
kubectl label namespace production kubernetes.io/metadata.name=production --overwrite
kubectl label namespace monitoring kubernetes.io/metadata.name=monitoring --overwrite

echo "==> [6/6] Creating RBAC for GitHub Actions OIDC..."
# The OIDC subject format from GitHub Actions:
#   repo:<owner>/<repo>:ref:refs/heads/main
# After our oidc-username-prefix "actions-oidc:", it becomes:
#   actions-oidc:repo:<owner>/<repo>:ref:refs/heads/main
OIDC_SUBJECT="actions-oidc:repo:${GITHUB_REPO}:ref:refs/heads/main"

kubectl apply -f - <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: github-actions-deployer
rules:
  # Read cluster state for verification
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "namespaces"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
  # Needed to verify ArgoCD Application status
  - apiGroups: ["argoproj.io"]
    resources: ["applications"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: github-actions-deployer
subjects:
  - kind: User
    name: "${OIDC_SUBJECT}"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: github-actions-deployer
  apiGroup: rbac.authorization.k8s.io
EOF

echo ""
echo "==========================================="
echo " k3s installation complete!"
echo "==========================================="
echo " API Server: https://$(curl -s ifconfig.me):6443"
echo " OIDC bound to repo: ${GITHUB_REPO}"
echo ""
echo " Next: Run install-argocd.sh"
