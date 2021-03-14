#!/bin/sh

kubectl create configmap -n cardano cardano-config --from-file=config.json \
    --from-file=topology-bp.json \
    --from-file=topology-relays.json \
    --dry-run=client -o yaml | kubectl replace -f -
