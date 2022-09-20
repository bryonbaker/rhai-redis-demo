#! /bin/bash

podman run --rm -d --name redis_database -p 6379:6379 rhel8/redis-6

