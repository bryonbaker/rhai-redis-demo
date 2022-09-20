#! /bin/bash

skupper delete
skupper init --site-name ibm-cloud --console-auth=internal --console-user=admin --console-password=password
skupper token create --token-type cert ibm-cloud.yaml

echo "Deploying Redis-2 server"
oc apply -f ../skupper-redis/redis-2.yaml
echo "Deploying Redis-3 server"
oc apply -f ../skupper-redis/redis-3.yaml
echo "Deploying Redis-4 server"
oc apply -f ../skupper-redis/redis-4.yaml
