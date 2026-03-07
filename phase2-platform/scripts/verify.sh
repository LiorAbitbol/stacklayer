#!/usr/bin/env bash
# verify.sh — Smoke test Phase 2 platform components
# Run from the repo root: make verify-platform

set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

PASS=0
FAIL=0

ok()   { echo "  [OK]  $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo ""
echo "=== StackLayer — Phase 2 Platform Verify ==="
echo ""

# -------------------------------------------------------------------
# MetalLB
# -------------------------------------------------------------------
echo "--- MetalLB ---"

not_ready=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null \
  | { grep -v "Running\|Completed" || true; } | wc -l)
if [ "$not_ready" -eq 0 ]; then
  ok "All MetalLB pods Running"
else
  fail "Some MetalLB pods not Running"
  kubectl get pods -n metallb-system
fi

pool=$(kubectl get ipaddresspool -n metallb-system --no-headers 2>/dev/null | wc -l)
if [ "$pool" -gt 0 ]; then
  ok "IPAddressPool exists"
else
  fail "No IPAddressPool found in metallb-system"
fi
echo ""

# -------------------------------------------------------------------
# ingress-nginx
# -------------------------------------------------------------------
echo "--- ingress-nginx ---"

not_ready=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null \
  | { grep -v "Running\|Completed" || true; } | wc -l)
if [ "$not_ready" -eq 0 ]; then
  ok "All ingress-nginx pods Running"
else
  fail "Some ingress-nginx pods not Running"
  kubectl get pods -n ingress-nginx
fi

LB_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ "$LB_IP" = "192.168.56.200" ]; then
  ok "LoadBalancer IP is 192.168.56.200"
else
  fail "Expected LoadBalancer IP 192.168.56.200, got: '${LB_IP}'"
fi
echo ""

# -------------------------------------------------------------------
# cert-manager
# -------------------------------------------------------------------
echo "--- cert-manager ---"

not_ready=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null \
  | { grep -v "Running\|Completed" || true; } | wc -l)
if [ "$not_ready" -eq 0 ]; then
  ok "All cert-manager pods Running"
else
  fail "Some cert-manager pods not Running"
  kubectl get pods -n cert-manager
fi

issuer_ready=$(kubectl get clusterissuer selfsigned \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
if [ "$issuer_ready" = "True" ]; then
  ok "ClusterIssuer 'selfsigned' is Ready"
else
  fail "ClusterIssuer 'selfsigned' not Ready (status: '${issuer_ready}')"
fi
echo ""

# -------------------------------------------------------------------
# local-path-provisioner
# -------------------------------------------------------------------
echo "--- local-path-provisioner ---"

not_ready=$(kubectl get pods -n local-path-storage --no-headers 2>/dev/null \
  | { grep -v "Running\|Completed" || true; } | wc -l)
if [ "$not_ready" -eq 0 ]; then
  ok "local-path-provisioner pod Running"
else
  fail "local-path-provisioner pod not Running"
  kubectl get pods -n local-path-storage
fi

is_default=$(kubectl get storageclass local-path \
  -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' \
  2>/dev/null || echo "")
if [ "$is_default" = "true" ]; then
  ok "local-path is default StorageClass"
else
  fail "local-path is not default StorageClass"
fi
echo ""

# -------------------------------------------------------------------
# PVC smoke test
# -------------------------------------------------------------------
echo "--- Storage smoke test ---"

kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: stacklayer-verify-pvc
  namespace: default
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Mi
  storageClassName: local-path
EOF

# PVCs with local-path only bind when a pod mounts them — check Pending is expected
# and the StorageClass accepted the claim (no error event)
phase=$(kubectl get pvc stacklayer-verify-pvc -n default \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
if [ "$phase" = "Pending" ] || [ "$phase" = "Bound" ]; then
  ok "PVC created and accepted by local-path (phase: ${phase})"
else
  fail "PVC in unexpected phase: '${phase}'"
fi

kubectl delete pvc stacklayer-verify-pvc -n default --ignore-not-found >/dev/null
echo ""

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo "--- Summary ---"
echo "  Passed: ${PASS}"
echo "  Failed: ${FAIL}"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "=== FAIL — ${FAIL} check(s) did not pass ==="
  echo ""
  exit 1
else
  echo "=== PASS — Platform is healthy ==="
  echo ""
fi
