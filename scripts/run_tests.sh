#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/3] Checking Nginx /health endpoint on port 8081 ==="
CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/health || echo "000")
echo "HTTP Status: $CODE"
[[ "$CODE" == "200" ]]

echo "=== [2/3] Validating Puppet manifest inside puppet-enforcer container ==="
docker exec int333-puppet-enforcer puppet parser validate /etc/puppetlabs/code/environments/production/manifests/site.pp

echo "=== [3/3] Simulating outage & verifying controlled recovery ==="
docker stop int333-nginx-service >/dev/null
sleep 2
docker compose up -d web-service >/dev/null
sleep 2
RECOVER_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/health || echo "000")
echo "Post-Recovery HTTP Status: $RECOVER_CODE"
[[ "$RECOVER_CODE" == "200" ]]

echo "ALL DEVOPS CHECKS PASSED!"
