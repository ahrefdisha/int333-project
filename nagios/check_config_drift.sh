#!/bin/sh
EXPECTED=$(sha256sum /opt/manifests/baseline_nginx.conf | awk '{print $1}' | cut -c1-12)
CURRENT=$(sha256sum /opt/config/nginx.conf | awk '{print $1}' | cut -c1-12)

if [ "$EXPECTED" = "$CURRENT" ]; then
    echo "OK - Configuration enforced and verified (SHA256: $CURRENT)"
    exit 0
else
    echo "CRITICAL - Configuration drift detected! Expected $EXPECTED got $CURRENT"
    exit 2
fi
