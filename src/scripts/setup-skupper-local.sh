#! /bin/bash

skupper delete
rm ibm-cloud.yaml
skupper init --site-name local --console-auth=internal --console-user=admin --console-password=password

echo "Waiting for ibm-cloud.yaml token file to be created. Please set up the other site now."
while [ ! -f ibm-cloud.yaml ]; do sleep 1; done
echo "Token file found."

skupper link create ibm-cloud.yaml

echo "Deploying Redis-0 server"
oc apply -f ../skupper-redis/redis-0.yaml
echo "Deploying Redis-1 server"
oc apply -f ../skupper-redis/redis-1.yaml

# rm -rf ~/.local/share/skupper/
skupper gateway init --type=podman
skupper gateway forward skupper-redis-server-0 6379
