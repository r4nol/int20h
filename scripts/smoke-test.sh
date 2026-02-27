#!/usr/bin/env bash
# smoke-test.sh — Basic end-to-end smoke tests after deployment
set -euo pipefail

VM_IP="${1:?Usage: $0 <VM_IP>}"

PASS=0
FAIL=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "${cmd}" > /dev/null 2>&1; then
    echo "  ✅ PASS: ${name}"
    PASS=$((PASS + 1))
  else
    echo "  ❌ FAIL: ${name}"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== Online Boutique Smoke Tests ==="
echo "    VM: ${VM_IP}"
echo ""

echo "--- HTTP Endpoints ---"
check "Production frontend responds (HTTP 200)" \
  "curl -sf --max-time 10 http://${VM_IP}:30080 -o /dev/null"
check "Staging frontend responds (HTTP 200)" \
  "curl -sf --max-time 10 http://${VM_IP}:30180 -o /dev/null"
check "ArgoCD UI responds (HTTPS)" \
  "curl -sfk --max-time 10 https://${VM_IP}:30443 -o /dev/null"
check "Grafana UI responds (HTTP 200)" \
  "curl -sf --max-time 10 http://${VM_IP}:30300 -o /dev/null"

echo ""
echo "--- Production Shop Navigation ---"
check "Product catalog page" \
  "curl -sf --max-time 10 http://${VM_IP}:30080/product/OLJCESPC7Z -o /dev/null"
check "Cart page accessible" \
  "curl -sf --max-time 10 http://${VM_IP}:30080/cart -o /dev/null"
check "Health check endpoint" \
  "curl -sf --max-time 10 -H 'Cookie: shop_session-id=smoke-test' http://${VM_IP}:30080/_healthz -o /dev/null"

echo ""
echo "--- Grafana API ---"
check "Grafana health API" \
  "curl -sf --max-time 10 http://${VM_IP}:30300/api/health -o /dev/null"
check "Grafana dashboards list" \
  "curl -sf --max-time 10 http://${VM_IP}:30300/api/search?type=dash-db | grep -q 'online-boutique-red'"

echo ""
echo "==================================="
echo " Results: ${PASS} passed, ${FAIL} failed"
echo "==================================="

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
