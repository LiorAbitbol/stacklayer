#!/usr/bin/env bash
# verify.sh — Smoke test Phase 4 observability components
# Run from the repo root: make verify-observability

set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

PASS=0
FAIL=0

ok()   { echo "  [OK]  $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo ""
echo "=== StackLayer — Phase 4 Observability Verify ==="
echo ""

# -------------------------------------------------------------------
# Prometheus
# -------------------------------------------------------------------
echo "--- Prometheus ---"

not_ready=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus \
  --no-headers 2>/dev/null | { grep -v "Running\|Completed" || true; } | wc -l)
if [ "$not_ready" -eq 0 ]; then
  ok "Prometheus pod Running"
else
  fail "Prometheus pod not Running"
  kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
fi

pvc_phase=$(kubectl get pvc -n monitoring \
  -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null \
  | awk '{print $2}' | head -1)
if [ "$pvc_phase" = "Bound" ]; then
  ok "Prometheus PVC Bound"
else
  fail "Prometheus PVC not Bound (phase: '${pvc_phase}')"
fi
echo ""

# -------------------------------------------------------------------
# Grafana
# -------------------------------------------------------------------
echo "--- Grafana ---"

not_ready=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana \
  --no-headers 2>/dev/null | { grep -v "Running\|Completed" || true; } | wc -l)
if [ "$not_ready" -eq 0 ]; then
  ok "Grafana pod Running"
else
  fail "Grafana pod not Running"
  kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
fi

pvc_phase=$(kubectl get pvc -n monitoring \
  -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null \
  | awk '{print $2}' | head -1)
if [ "$pvc_phase" = "Bound" ]; then
  ok "Grafana PVC Bound"
else
  fail "Grafana PVC not Bound (phase: '${pvc_phase}')"
fi

ingress=$(kubectl get ingress grafana -n monitoring --no-headers 2>/dev/null | wc -l)
if [ "$ingress" -gt 0 ]; then
  ok "Grafana ingress exists"
else
  fail "Grafana ingress not found"
fi
echo ""

# -------------------------------------------------------------------
# Alertmanager
# -------------------------------------------------------------------
echo "--- Alertmanager ---"

not_ready=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager \
  --no-headers 2>/dev/null | { grep -v "Running\|Completed" || true; } | wc -l)
if [ "$not_ready" -eq 0 ]; then
  ok "Alertmanager pod Running"
else
  fail "Alertmanager pod not Running"
  kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager
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
  echo "=== PASS — Observability stack is healthy ==="
  echo ""
  echo "  Grafana: https://grafana.stacklayer.local  (admin / stacklayer)"
  echo ""
fi
