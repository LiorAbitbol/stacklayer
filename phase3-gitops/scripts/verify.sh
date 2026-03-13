#!/usr/bin/env bash
# verify.sh — Smoke test Phase 3 GitOps (ArgoCD)
# Run from the repo root: make verify-gitops

set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

PASS=0
FAIL=0

ok()   { echo "  [OK]  $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo ""
echo "=== StackLayer — Phase 3 GitOps Verify ==="
echo ""

# -------------------------------------------------------------------
# ArgoCD pods
# -------------------------------------------------------------------
echo "--- ArgoCD pods ---"

not_ready=$(kubectl get pods -n argocd --no-headers 2>/dev/null \
  | { grep -v "Running\|Completed" || true; } | wc -l)
if [ "$not_ready" -eq 0 ]; then
  ok "All ArgoCD pods Running"
else
  fail "Some ArgoCD pods not Running"
  kubectl get pods -n argocd
fi
echo ""

# -------------------------------------------------------------------
# ArgoCD server deployment
# -------------------------------------------------------------------
echo "--- ArgoCD server ---"

ready=$(kubectl get deployment argocd-server -n argocd \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${ready}" -ge 1 ]; then
  ok "argocd-server deployment is ready (${ready} replica(s))"
else
  fail "argocd-server deployment not ready"
fi
echo ""

# -------------------------------------------------------------------
# Ingress
# -------------------------------------------------------------------
echo "--- Ingress ---"

ingress_host=$(kubectl get ingress argocd-server -n argocd \
  -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
if [ "${ingress_host}" = "argocd.stacklayer.local" ]; then
  ok "Ingress host is argocd.stacklayer.local"
else
  fail "Ingress host unexpected: '${ingress_host}'"
fi

tls_secret=$(kubectl get ingress argocd-server -n argocd \
  -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null || echo "")
if [ "${tls_secret}" = "argocd-tls" ]; then
  ok "TLS secret configured (${tls_secret})"
else
  fail "TLS secret unexpected: '${tls_secret}'"
fi
echo ""

# -------------------------------------------------------------------
# TLS certificate issued by cert-manager
# -------------------------------------------------------------------
echo "--- TLS certificate ---"

cert_ready=$(kubectl get certificate argocd-tls -n argocd \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
if [ "${cert_ready}" = "True" ]; then
  ok "TLS certificate is Ready"
else
  fail "TLS certificate not Ready (status: '${cert_ready}')"
fi
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
  echo "=== PASS — ArgoCD is healthy ==="
  echo ""
  echo "  URL:      https://argocd.stacklayer.local"
  echo "  Username: admin"
  echo "  Password: stacklayer"
  echo ""
fi
