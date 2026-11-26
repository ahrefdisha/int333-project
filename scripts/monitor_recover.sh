#!/usr/bin/env bash
set -euo pipefail

SERVICE_URL="http://localhost:8081/health"
CONTAINER_NAME="int333-nginx-service"
CONFIG_FILE="config/nginx.conf"
GOLDEN_CONFIG="manifests/baseline_nginx.conf"
LOG_FILE="logs/incident.jsonl"
METRICS_FILE="metrics/metrics.prom"

mkdir -p logs metrics

DRIFT_COUNT=0
RECOVERY_COUNT=0
EXPECTED_HASH=$(shasum -a 256 "$GOLDEN_CONFIG" | awk '{print $1}')

write_metrics() {
  local up_val=$1
  cat << METRICS > "$METRICS_FILE"
# HELP int333_service_up Whether the Nginx web service is healthy (1 = UP, 0 = DOWN)
# TYPE int333_service_up gauge
int333_service_up $up_val
# HELP int333_config_drift_total Total number of configuration drift events remediated
# TYPE int333_config_drift_total counter
int333_config_drift_total $DRIFT_COUNT
# HELP int333_recovery_total Total number of automated container recoveries
# TYPE int333_recovery_total counter
int333_recovery_total $RECOVERY_COUNT
METRICS
}

log_event() {
  local level=$1
  local event=$2
  local detail=$3
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"timestamp\":\"$ts\",\"level\":\"$level\",\"event\":\"$event\",\"detail\":\"$detail\"}" | tee -a "$LOG_FILE"
}

log_event "INFO" "AGENT_START" "SRE Enforcement & Recovery Agent active (Expected SHA256: ${EXPECTED_HASH:0:12})"

while true; do
  # 1. Configuration Drift Check & Puppet Golden-State Remediation
  CURRENT_HASH=$(shasum -a 256 "$CONFIG_FILE" | awk '{print $1}')
  if [[ "$CURRENT_HASH" != "$EXPECTED_HASH" ]]; then
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    log_event "WARN" "CONFIG_DRIFT_DETECTED" "Hash mismatch (${CURRENT_HASH:0:12} != ${EXPECTED_HASH:0:12}). Enforcing golden config..."
    cp "$GOLDEN_CONFIG" "$CONFIG_FILE"
    docker exec "$CONTAINER_NAME" nginx -s reload >/dev/null 2>&1 || docker compose up -d web-service >/dev/null
    log_event "RECOVERED" "CONFIG_ENFORCED" "Configuration restored from Puppet golden baseline and Nginx reloaded"
  fi

  # 2. Uptime Health Check & Controlled Container Recovery
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL" || echo "000")
  if [[ "$HTTP_CODE" != "200" ]]; then
    RECOVERY_COUNT=$((RECOVERY_COUNT + 1))
    write_metrics 0
    log_event "CRITICAL" "SERVICE_OUTAGE" "Endpoint $SERVICE_URL returned HTTP $HTTP_CODE. Triggering controlled recovery..."
    docker compose up -d web-service >/dev/null
    sleep 2
    POST_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL" || echo "000")
    if [[ "$POST_CODE" == "200" ]]; then
      write_metrics 1
      log_event "RECOVERED" "SERVICE_RESTORED" "Service recovered successfully (HTTP 200)"
    fi
  else
    write_metrics 1
    echo "[$(date '+%H:%M:%S')] [HEALTHY] HTTP 200 | Config: ENFORCED | Drifts Fixed: $DRIFT_COUNT | Recoveries: $RECOVERY_COUNT"
  fi

  sleep 5
done
