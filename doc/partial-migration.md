# Migrate a Redis Client to Cloud

The demonstration start by demonstrating the initial application. It is two apps that sdhare a cache. One writes to the cache, the other reads from the cache.

## Start the Redis Server on Preimises

Start the Redis Cache in Pdman
```
./start-redis-local.sh
```
## Run the Redis Reader App
Start the reader applicatin. It will yield no results until the writer is run once.


```
bin/redis-tester --read
```


Output:
```
$ bin/redis-tester --read
Loading configuration
map[database:0 db-password: server-address:rh-brbaker-bakerapps-net:6379]
Reddis connection:  Redis<rh-brbaker-bakerapps-net:6379 db:0>
Context: context.Background
Redis Reader
ReadFromChache()
Key " key " returned no result.
Result: {" key "}:{"  "}
Key " key " returned no result.
Result: {" key "}:{"  "}
Key " key " returned no result.
Result: {" key "}:{"  "}
```

## Run the Redis Writer App

Run the Redis Writer
```
bin/redis-tester --write
```

```
$ bin/redis-tester --write
Loading configuration
map[database:0 db-password: server-address:rh-brbaker-bakerapps-net:6379]
Reddis connection:  Redis<rh-brbaker-bakerapps-net:6379 db:0>
Context: context.Background
Cache Writer
WriteToChache()
Write successful: {" key "}:{" asbestoses-squiffer "}
```

This will write a random string to the cache. Observe the output from the reader.  

```
Result: {" key "}:{"  "}
Key " key " returned no result.
Result: {" key "}:{"  "}
Result: {" key "}:{" asbestoses-squiffer "}
Result: {" key "}:{" asbestoses-squiffer "}
Result: {" key "}:{" asbestoses-squiffer "}
```

# Move the Reader to the On Premises OpenShift

## Preconditions
1. You are logged on to OpenShift Local  
2. A ```redis-demo``` namespace has been created and is the current project.

## Step 1: Create an isolated OpenShift command-line environment

```
bryon@rh-brbaker-bakerapps-net:environment$ . ./env-setup-local.sh 
LOCAL: bryon@rh-brbaker-bakerapps-net:environment$
```

## Stewp 2: Install Skupper
```
$ LOCAL:$ skupper init --site-name local --console-auth=internal --console-user=admin --console-password=password

Skupper is now installed in namespace 'redis-demo'.  Use 'skupper status' to get more information.
```

## Expose the On Premises Redis Cache to OpenShift
```
LOCAL:$ skupper gateway expose skupper-redis-server-2 127.0.0.1 6379 --type podman

2022/09/20 16:38:44 CREATE io.skupper.router.tcpConnector rh-brbaker-bakerapps-net-bryon-egress-skupper-redis-server-2:6379 map[address:skupper-redis-server-2:6379 host:127.0.0.1 name:rh-brbaker-bakerapps-net-bryon-egress-skupper-redis-server-2:6379 port:6379 siteId:6bc7d681-046a-44e8-9dd3-cb6f82ad8127]
```

Observe a service proxy is created on OpenShift
```
$ oc get svc
NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)               AGE
skupper                  ClusterIP   10.217.4.40    <none>        8080/TCP,8081/TCP     4m6s
skupper-redis-server-2   ClusterIP   10.217.4.219   <none>        6379/TCP              62s
skupper-router           ClusterIP   10.217.5.64    <none>        55671/TCP,45671/TCP   4m8s
skupper-router-local     ClusterIP   10.217.5.85    <none>        5671/TCP              4m8s
```

## Deploy the application to OpenShift

```
LOCAL:$ oc apply -f ../src/yaml/app-config-cm.yaml 
configmap/app-config created
```
```
LOCAL:$ oc apply -f ../src/yaml/redis-reader-dep.yaml 
deployment.apps/redis-read-tester created
```

### Observer the OpenShift Application accessing the cache
Find the pod running the reader
```
LOCAL: bryon@rh-brbaker-bakerapps-net:environment$ oc get pods
NAME                                          READY   STATUS    RESTARTS   AGE
redis-read-tester-694c59dfbc-lkww5            1/1     Running   0          94s
skupper-router-75bc9db8db-56nh5               2/2     Running   0          7m
skupper-service-controller-5496fcbc48-dtdpl   1/1     Running   0          6m58s
```

Attach to the pod and show the cache value is still the same

```
LOCAL: bryon@rh-brbaker-bakerapps-net:environment$ oc attach pod/redis-read-tester-694c59dfbc-lkww5
If you don't see a command prompt, try pressing enter.
Result: {" key "}:{" asbestoses-squiffer "}
Result: {" key "}:{" asbestoses-squiffer "}

```

Run the writer again and observe the cache is updated:

### Writer
```
$ bin/redis-tester --write
Loading configuration
map[database:0 db-password: server-address:rh-brbaker-bakerapps-net:6379]
Reddis connection:  Redis<rh-brbaker-bakerapps-net:6379 db:0>
Context: context.Background
Cache Writer
WriteToChache()
Write successful: {" key "}:{" Gillsville-unimpertinently "}
```

### Reader
```
$ oc attach pod/redis-read-tester-694c59dfbc-lkww5
If you don't see a command prompt, try pressing enter.
Result: {" key "}:{" asbestoses-squiffer "}
Result: {" key "}:{" asbestoses-squiffer "}
Result: {" key "}:{" asbestoses-squiffer "}
Result: {" key "}:{" asbestoses-squiffer "}
Result: {" key "}:{" Gillsville-unimpertinently "}
Result: {" key "}:{" Gillsville-unimpertinently "}
Result: {" key "}:{" Gillsville-unimpertinently "}
Result: {" key "}:{" Gillsville-unimpertinently "}
Result: {" key "}:{" Gillsville-unimpertinently "}
```

## Migrate the Reader to the Public Cloud

1. Create an IBM Console in a new terminal window
```
bryon@rh-brbaker-bakerapps-net:environment$ . ./env-setup-ibm.sh 
IBM-CLOUD: bryon@rh-brbaker-bakerapps-net:environment$
```

2. Deploy Skupper into the ```redis-demo``` project  
```
IBM-CLOUD:$ skupper init --site-name ibm-cloud --console-auth=internal --console-user=admin --console-password=password  

Skupper is now installed in namespace 'redis-demo'.  Use 'skupper status' to get more information.
```
3. Create a secure token
```
IBM-CLOUD:$  skupper token create --token-type cert ibm-cloud.yaml
Connection token written to ibm-cloud.yaml
```

4. Change to the LOCAL console
5. Import the secure token to establish the Skupper network

## View the Skupper Console

```
LOCAL:$ oc get route
NAME                   HOST/PORT                                          PATH   SERVICES         PORT           TERMINATION            WILDCARD
claims                 claims-redis-demo.apps-crc.testing                        skupper          claims         passthrough/Redirect   None
skupper                skupper-redis-demo.apps-crc.testing                       skupper          metrics        reencrypt/Redirect     None
skupper-edge           skupper-edge-redis-demo.apps-crc.testing                  skupper-router   edge           passthrough/None       None
skupper-inter-router   skupper-inter-router-redis-demo.apps-crc.testing          skupper-router   inter-router   passthrough/None       None
```

Your output may differ, but in this example the skupper router url is: ```skupper-redis-demo.apps-crc.testing```   

Open a browser with the url of the skupper router
The username is ```admin```. The password is ```password```.  

<img src="./images/rhai-1.png" alt="drawing" width="800"/>

<img src="./images/rhai-2.png" alt="drawing" width="800"/>

<img src="./images/rhai-3.png" alt="drawing" width="800"/>


