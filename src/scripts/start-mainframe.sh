#! /bin/bash
podman play kube yaml/podman-redis.yaml
sleep 10
podman run -d --rm --network="host" --name write-tester quay.io/brbaker/redis-write-tester:latest
podman attach write-tester

