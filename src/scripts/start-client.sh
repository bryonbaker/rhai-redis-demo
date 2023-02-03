#! /bin/bash

podman run -d --rm --network="host" --name read-tester quay.io/brbaker/redis-read-tester:latest
podman attach read-tester
