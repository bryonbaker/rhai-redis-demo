#! /bin/bash

oc delete -f ../src/yaml/app-config-cm.yaml
oc delete -f ../src/yaml/redis-reader-dep.yaml

skupper delete
oc delete -f ../skupper-redis/redis-2.yaml
oc delete -f ../skupper-redis/redis-3.yaml
oc delete -f ../skupper-redis/redis-4.yaml
