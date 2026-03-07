#!/usr/bin/env bash
# worker-join.sh — Runs on k8s-worker-1 and k8s-worker-2
# Waits for the master to write the join command, then joins the cluster

set -euo pipefail

JOIN_COMMAND_FILE="/vagrant/join-command.sh"
MAX_WAIT=120   # seconds
INTERVAL=5

echo "==> [worker] Waiting for join command from master..."
elapsed=0
until [ -f "${JOIN_COMMAND_FILE}" ]; do
  if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: Timed out waiting for ${JOIN_COMMAND_FILE} after ${MAX_WAIT}s"
    echo "       Make sure the master has finished provisioning."
    exit 1
  fi
  echo "    ${JOIN_COMMAND_FILE} not found yet, retrying in ${INTERVAL}s... (${elapsed}s elapsed)"
  sleep "${INTERVAL}"
  elapsed=$(( elapsed + INTERVAL ))
done

echo "==> [worker] Join command found. Joining cluster..."
bash "${JOIN_COMMAND_FILE}"

echo "==> [worker] Done. This node has joined the cluster."
