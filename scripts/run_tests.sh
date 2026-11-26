#!/usr/bin/env bash
set -euo pipefail

echo "=== [1/4] Verifying Web Service Health (HTTP 200) ==="
CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/health || echo "000")
echo "Health Status: $CODE"
[[ "$CODE" == "200" ]]

echo "=== [2/4] Verifying Puppet Manifest & Enforcement ==="
docker exec int333-puppet-enforcer puppet parser validate /etc/puppetlabs/code/environments/production/manifests/site.pp

echo "=== [3/4] Simulating Config Drift & Puppet Self-Healing ==="
echo "# unauthorized edit" >> config/nginx.conf
docker exec int333-puppet-enforcer puppet apply -e "file { '/opt/enforced-config/nginx.conf': ensure => file, source => '/etc/puppetlabs/code/environments/production/manifests/baseline_nginx.conf' }"
grep -q "unauthorized edit" config/nginx.conf && exit 1 || echo "Config drift automatically remediated by Puppet!"

echo "=== [4/4] Simulating Outage & Controlled Recovery ==="
docker stop int333-nginx-service >/dev/null
sleep 2
docker compose up -d web-service >/dev/null
sleep 2
POST_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/health || echo "000")
echo "Post-Recovery Status: $POST_CODE"
[[ "$POST_CODE" == "200" ]]

echo "ALL REAL-WORLD SRE CHECKS PASSED!"
