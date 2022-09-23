#! /bin/bash

skupper gateway expose skupper-redis-on-prem-server-0 127.0.0.1 6379 26379 --type podman
