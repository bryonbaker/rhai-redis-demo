#! /bin/bash

oc delete -f ../src/yaml/app-config-cm.yaml
oc delete -f ../src/yaml/redis-reader-dep.yaml

skupper delete
oc delete -f ../skupper-redis/redis-0.yaml
oc delete -f ../skupper-redis/redis-1.yaml

skupper gateway delete
skupper rm -rf ~/.local/share/skupper
