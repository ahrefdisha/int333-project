#!/bin/sh
EXPECTED=$(sha256sum /opt/manifests/baseline_nginx.conf | awk '{print $1}')
CURRENT=$(sha256sum /opt/config/nginx.conf | awk '{print $1}')

if [ "$EXPECTED" = "$CURRENT" ]; then
    echo "OK - Configuration enforced and verified (SHA256: ${CURRENT:0:12})"
    exit 0
else
    echo "CRITICAL - Configuration drift detected! Expected ${EXPECTED:0:12} got ${CURRENT:0:12}"
    exit 2
fi
