#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="int333-nginx-service"
HEALTH_URL="http://localhost:8081/health"
CONFIG_FILE="./config/nginx.conf"
BASELINE_HASH_FILE="./logs/.config.sha256"
LOG_FILE="./logs/incident.log"

mkdir -p ./logs
touch "$LOG_FILE"

shasum -a 256 "$CONFIG_FILE" | awk '{print $1}' > "$BASELINE_HASH_FILE"

log_event() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

log_event "INFO" "Starting DevOps Uptime & Configuration Enforcement Agent for $SERVICE_NAME"

while true; do
  CURRENT_HASH=$(shasum -a 256 "$CONFIG_FILE" | awk '{print $1}')
  EXPECTED_HASH=$(cat "$BASELINE_HASH_FILE")

  if [[ "$CURRENT_HASH" != "$EXPECTED_HASH" ]]; then
    log_event "WARNING" "Configuration drift detected in $CONFIG_FILE! Re-enforcing baseline configuration..."
    git checkout -- "$CONFIG_FILE" 2>/dev/null || true
    docker compose restart web-service >/dev/null 2>&1 || docker compose up -d >/dev/null 2>&1
    shasum -a 256 "$CONFIG_FILE" | awk '{print $1}' > "$BASELINE_HASH_FILE"
    log_event "RECOVERED" "Configuration drift resolved and $SERVICE_NAME reloaded."
  fi

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "000")

  if [[ "$HTTP_CODE" == "200" ]]; then
    log_event "UP" "Endpoint $HEALTH_URL healthy (HTTP 200) | Config: ENFORCED"
  else
    log_event "DOWN" "Outage detected on $HEALTH_URL (HTTP $HTTP_CODE). Initiating controlled recovery..."
    docker compose up -d >/dev/null 2>&1
    sleep 2
    RETRY_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "000")
    if [[ "$RETRY_CODE" == "200" ]]; then
      log_event "RECOVERED" "Controlled recovery succeeded for $SERVICE_NAME (HTTP 200)."
    else
      log_event "CRITICAL" "Recovery failed for $SERVICE_NAME (HTTP $RETRY_CODE)."
    fi
  fi

  sleep 5
done
