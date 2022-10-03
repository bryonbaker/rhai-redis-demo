# Building a Global Redis Cache with OpenShift and Red Hat Application Interconnect (aka Skupper)

## TODO:
* Spell check, review and edit. =:-D
* Skupper installation details
* OpenShift Local installation details
* Elaborate on the instructions on setting up the isolated environments.
* Move redis-reader into a container so people don't have to build the on-premises client.

## Background

The goal is to progressively extend an on-premises cache out to the cloud to create a global cache of readonly data.

This is a common pattern to protect core systems from Internet-scale workloads. A practical example in Banking and Finance is that over 90% of transactions from mobile devices are balance enquiries. Banks often set an SLA of an account balance being updated with 10 seconds of a transaction. After a deposit, withdrawal, or transfer the mainframe updates the account balance in a strip file and the new balance is written to a cache that is replicated close to all of the systems of engagement. As users enquire on their balance, their query is serviced locally and does not need to hit the mainframe - significantly reducing mainframe costs and protecting the mainframe from bursty workloads.

Building a globally-distributed cache with Redis and Kubernetes is traditionally difficult and complex because Redis requires TCP. To implement this without Application Interconnect you would need a global WAN and use NodePorts, Federated Service Mesh, or Submariner. These solutions are complex and difficult to implement and manage at scale.

This demonstration illustrates how [Application Interconnect](https://access.redhat.com/documentation/en-us/red_hat_application_interconnect/) simplifies application interconnectivity requirements, and enables progressive cloud migration of workloads.

The demonstration uses four OpenShift clusters:
* On-premises (OpenShift Local)
* Sydney (IBM Cloud)
* London (AWS)
* New York (AWS)

At the end of this demonstration you will see how an on-premises core system writes to a cache master and it is replicated across the globe.

<img src="./images/rhai-finished.gif" alt="drawing" width="900"/>  

This demonstration leverages the innovative work of the Skupper project (https://skupper.io).

You need a separate command line environment for each cluster as described in the Skupper [Getting Started](https://skupper.io/start/index.html#configure-separate-console-sessions)

## Story Arc

The story starts by using on-premises OpenShift to get your application cloud ready. 
* You use Application Interconnect to provide a simple kubernetes-centric integration that distributes the cache from traditional infrastructure to Kubernetes.
* Once the cache is successfully being replicated you deploy a cache client on OpenShift. 
* Having successfully used OpenShift on-premises to get your application cloud ready, you can:
  * Extend the Application Interconnect network to OpenSHift running on IBM Cloud in Sydney.
  * Deploy a cache replica in Sydney
  * Deploy the cache reader in Sydney that uses the Sydney-based cache, demonstrating how a sydney-based deployment is reading a local Redis cache that is being updated from within the data centre.
* The demonstration repeats the process to add London and New York, demonstrating a global Redis cache powered by an "OpenShift Fabric" and Red Hat Application Interconnect.

# Configure the Demo Environment

## Tested Infrastructure
* This demo was built using Fedora 36 running [OpenShift Local](https://developers.redhat.com/products/openshift-local/overview) v4.10.
* The public cloud OpenShift instance was running on IBM Cloud. For convenience, three namespaces are used to simulate Sydney, London and New York.

## Requirments
* Each cluster must be network reachable from at least one other cluster.

## Get this demo
Clone this git repository and change directory into the src directory:
```
$ git clone https://github.com/bryonbaker/rhai-redis-demo
$ cd ./rhai-redis-demo/src
src$ 
```
**NOTE:** To illustrate the directory that you run commands from, the base directory is included in the commands. E.g. ```src$ cd yaml``` describes running the ```cd``` command from the ```src``` directory.

The demonstration starts by demonstrating the initial application. It is two on-premises applications that share a cache. One writes to the cache (the mainframe), the other reads from the cache (the cache client).


## Working Around DNS Resolution on the Demo Machine
First configure a workaround for resolving DNS hostnames from within a pod.

```
src$ sudo vi /etc/hosts
```
Add the following line to the end of the ```hosts``` file and save it:
```
127.0.0.1 skupper-redis-on-prem-server-0
```

## Start the Redis Server "On-Premises"

Start the Redis Cache in Podman. This is the on-premises ```Master Cache``` that all replicas are synchronised with. This is the cache that the "mainframe application" continuously writes to.

```
src$ podman play kube yaml/podman-redis.yaml
```

Podman launches the Redis cache and sentinel server in a Podman pod. Check the running state with ```podman ps```.
```
yaml$ podman ps
CONTAINER ID  IMAGE                                    COMMAND     CREATED             STATUS                 PORTS                                             NAMES
659e70e91727  localhost/podman-pause:4.2.0-1660228937              About a minute ago  Up About a minute ago  0.0.0.0:6379->6379/tcp, 0.0.0.0:26379->26379/tcp  7be728e5736e-infra
3cdc9ad23600  docker.io/library/redis:latest                       About a minute ago  Up About a minute ago  0.0.0.0:6379->6379/tcp, 0.0.0.0:26379->26379/tcp  redis-local-redis
b3008f5d8528  docker.io/library/redis:latest                       About a minute ago  Up About a minute ago  0.0.0.0:6379->6379/tcp, 0.0.0.0:26379->26379/tcp  redis-local-redis-sentinel
```

# Start of Demonstration

The core environment setup is now complete. The demonstration starts from here.

## Start the "Traditional Applications"

Open two terminal windows. Mainframe terminal is on the left, and the client terminal is on the right.
Change in to the ```src``` directory in both terminals

In the "Mainframe" terminal type:
```
src$ podman run -d --rm --network="host" --name write-tester quay.io/brbaker/redis-write-tester:latest
src$ podman attach write-tester
```
This downloads and starts a container that updates the local cache with a new entry every two seconds.

In the Client terminal type:
```
src$ podman run -d --rm --network="host" --name read-tester quay.io/brbaker/redis-read-tester:latest
src$ podman attach read-tester
```

You should now see the "Mainframe" updating the cache every two seconds, and the Client application reading the updated cache.

<img src="./images/on-prem-0.png" alt="drawing" width="900"/>

### Storyline
Here we are simulating a mainframe periodically writing to a cache, and an on-premises application retrieving the value from the cache. Because the client workload is based on customer activity, the load can be very "spikey". The use of a cache such as this is a common approach to protect the mainframe from unpredictable load and minimises mainframe costs.

### Demonstration Summary
1. First we install Application Interconnect on On-Premises OpenShift, and then install a Gateway on the same machine that is running the on-premises master Redis cache.
2. Once the RHAI components are in place we expose the on-premises cache to the OpenShift cluster so Client applications can access the cache.
3. We then refine this deployment to replicate the cache on OpenShift, and repoint the client application to use the cache replica.
4. By the end of ```step 3``` we have used OpenShift to get our application cloud ready and can now copy this deployment approach to create a globally-distributed cache with client applications able to access their local replica.


# Start the Progressive Migration to Cloud
The first stage in progressive migration is to make the Client Application cloud-ready and deploy it to the on-premises OpenShift. Application Interconnect simplifies this by creating a local service proxy for the cache master and enabling the OpenShift-hosted replica to synchronise using the proxy.

## Setup
1. Open a new terminal window. This terminal is dedicated to the "on-premises" steps.
Enter the following command. ```Note the additional period at the start (". ")```. You MUST include this period or a new shell is not created.  

```
src$ . ./scripts/env-setup-local.sh

ON-PREM: src$
```
Observe that the prompt changes to include ```ON-PREM```. This command created a terminal session with its own kubeconfig.  This provides a visual clue as to which OpenShift cluster you are working with.  

There is a different environment setup script per cluster. This allows you to have multiple logons to OpenShift clusters.  

We refer to this terminal as the ``` ON-PREM``` terminal.

2. Log onto the OpenShift local.
3. Create a new project:
```
ON-PREM: src$ oc new-project redis-demo
```

## Step 2: Install Skupper
```
ON-PREM:$ skupper init --site-name local --console-auth=internal --console-user=admin --console-password=password

Skupper is now installed in namespace 'redis-demo'.  Use 'skupper status' to get more information.
```

The username:password (```admin:password```) allows you to log into the Skupper console.

Get the routes from OpenShift:
```
ON-PREM: src$ oc get route/skupper
NAME      HOST/PORT                             PATH   SERVICES   PORT      TERMINATION          WILDCARD
skupper   skupper-redis-demo.apps-crc.testing          skupper    metrics   reencrypt/Redirect   None
ON-PREM: src$ 
```

Copy the route and paste it into your browser. When prompted for logon credentials enter:
```
Username: admin
Password: password
```
<img src="./images/rhai-console-0.png" alt="drawing" width="900"/>

### Create a Gateway to Publish the Redis Master to OpenShift

```
ON-PREM: src$skupper gateway expose skupper-redis-on-prem-server-0 127.0.0.1 6379 26379 --type podman

2022/09/24 11:04:59 CREATE io.skupper.router.tcpConnector rh-brbaker-bakerapps-net-bryon-egress-skupper-redis-on-prem-server-0:6379 map[address:skupper-redis-on-prem-server-0:6379 host:127.0.0.1 name:rh-brbaker-bakerapps-net-bryon-egress-skupper-redis-on-prem-server-0:6379 port:6379 siteId:92ed5d77-2b7c-4c7e-baab-3a09e88343c8]
2022/09/24 11:04:59 CREATE io.skupper.router.tcpConnector rh-brbaker-bakerapps-net-bryon-egress-skupper-redis-on-prem-server-0:26379 map[address:skupper-redis-on-prem-server-0:26379 host:127.0.0.1 name:rh-brbaker-bakerapps-net-bryon-egress-skupper-redis-on-prem-server-0:26379 port:26379 siteId:92ed5d77-2b7c-4c7e-baab-3a09e88343c8]
ON-PREM: src$
```

View the Gateway in the RHAI Console:

<img src="./images/rhai-console-1.png" alt="drawing" width="900"/>

```
ON-PREM: src$ oc get svc,pods
NAME                                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)               AGE
service/skupper                          ClusterIP   10.217.5.53    <none>        8080/TCP,8081/TCP     15m
service/skupper-redis-on-prem-server-0   ClusterIP   10.217.4.139   <none>        6379/TCP,26379/TCP    4m32s
service/skupper-router                   ClusterIP   10.217.5.84    <none>        55671/TCP,45671/TCP   15m
service/skupper-router-local             ClusterIP   10.217.5.56    <none>        5671/TCP              15m

NAME                                              READY   STATUS    RESTARTS   AGE
pod/skupper-router-b6f9947fd-pd89l                2/2     Running   0          15m
pod/skupper-service-controller-7cccd9467b-v9zgf   1/1     Running   0          15m
```

Observe that the Redis Master Cache is published as a service in the project, but there is no pod for the Redis Master. This is how RHAI creates a locationless application. It uses a Service Proxy and the RHAI Router routes requests to where the Service's implementation exists. Any call to the ```skupper-redis-on-prem-server-0``` service is redirected via the Gateway to the cache running on premises.

## Deploy the Client Application to OpenShift

```
ON-PREM: src$ cd yaml
ON-PREM: yaml$  oc apply -f redis-reader-on-prem-dep.yaml 

configmap/redis-reader-on-prem-app-config created
Warning: would violate PodSecurity "restricted:v1.24": allowPrivilegeEscalation != false (container "redis-read-tester" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "redis-read-tester" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "redis-read-tester" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "redis-read-tester" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
deployment.apps/redis-read-tester created
```

Get a list of the running pods:
```
yaml$ oc get pods
NAME                                          READY   STATUS    RESTARTS   AGE
redis-read-tester-7c474855bb-zfzvx            1/1     Running   0          5m26s
skupper-router-b6f9947fd-pd89l                2/2     Running   0          30m
skupper-service-controller-7cccd9467b-v9zgf   1/1     Running   0          30m
```

Attach to the Redis pod and observe the cache updates:
```
yaml$ oc attach pod/redis-read-tester-7c474855bb-zfzvx
If you don't see a command prompt, try pressing enter.
Result: {" key "}:{" foreschool-Amye "}
Result: {" key "}:{" foreschool-Amye "}
Result: {" key "}:{" entrapment-pleuropericardial "}
```

View the deployment in the RHAI Console. Observe the Client Application deployment is accessing the cache via the Gateway.  
<img src="./images/rhai-on-prem-0.png" alt="drawing" width="900"/>

Open the On-Premises OpenShift console and view the logs of the running Client Application. Scroll up on the logs and observe the server name for the cache is the on-premises cache:
<img src="./images/rhai-on-prem-1.png" alt="drawing" width="900"/>

At no point was a global DNS entry required, the Gateway is part of the RHAI application's network.

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

## Set up the OpenShift Fabric

### Story Arc

One of the key value propositions of the Red Hat Open Hybrid cloud is the ability to create an "OpenShift Fabric" that lets you get your workloads 100% ready for the public cloud, and then redeploy those workloads as-is with only an endpoint configuration change.

In this section of the demonstration we set up OpenShift on-premises as a true stepping stone for the public cloud deployments.

So far we have deployed the Client Application to on-premises OpenShift. Now we create a cache replica on OpenShift. Once we have that we will be able to repeat the pattern of cache/application deployment globally.

### Deploy Redis to OpenSHift On-Premises
```
ON-PREM: yaml$ oc apply -f redis-on-prem-ocp-dep.yaml 

deployment.apps/skupper-redis-server-1 created
configmap/skupper-redis-server-1 created
```

Attach to the TRedis pod and validate the cache is replicating:

```
ON-PREM: yaml$ oc get pods | grep skupper-redis
skupper-redis-server-1-6bb44b65b5-mfgbv       2/2     Running   0          3m35s


ON-PREM: yaml$ $ oc exec -it skupper-redis-server-1-6bb44b65b5-mfgbv -c redis -- /bin/bash
1000670000@skupper-redis-server-1-6bb44b65b5-mfgbv:/data$ 
```
Enter ```redis-cli get key``` and press ```Enter```. Observe the cache value changing:
```
1000670000@skupper-redis-server-1-6bb44b65b5-mfgbv:/data$ redis-cli get key
"viscousness-seagulls"
1000670000@skupper-redis-server-1-6bb44b65b5-mfgbv:/data$ redis-cli get key
"illocality-griffe"
1000670000@skupper-redis-server-1-6bb44b65b5-mfgbv:/data$
```

Press ```Ctrl-D``` to exit the running container
```
1000670000@skupper-redis-server-1-6bb44b65b5-mfgbv:/data$ 
exit
command terminated with exit code 130
ON-PREM: yaml$ 
```

### Expose the On-Premises OpenShift Cache to the RHAI Network
View the current deployments and services
```
ON-PREM: yaml$ oc get deployment,svc
NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/redis-read-tester            1/1     1            1           32m
deployment.apps/skupper-redis-server-1       1/1     1            1           9m59s
deployment.apps/skupper-router               1/1     1            1           58m
deployment.apps/skupper-service-controller   1/1     1            1           58m

NAME                                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)               AGE
service/skupper                          ClusterIP   10.217.5.53    <none>        8080/TCP,8081/TCP     58m
service/skupper-redis-on-prem-server-0   ClusterIP   10.217.4.139   <none>        6379/TCP,26379/TCP    47m
service/skupper-router                   ClusterIP   10.217.5.84    <none>        55671/TCP,45671/TCP   58m
service/skupper-router-local             ClusterIP   10.217.5.56    <none>        5671/TCP              58m
```

We can now expose the ```skupper-redis-server-1``` deployment to the RHAI mesh network.

```
ON-PREM: yaml$ skupper expose deployment skupper-redis-server-1 --port 6379,26379

deployment skupper-redis-server-1 exposed as skupper-redis-server-1

ON-PREM: yaml$ oc get deployment,svc
NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/redis-read-tester            1/1     1            1           37m
deployment.apps/skupper-redis-server-1       1/1     1            1           14m
deployment.apps/skupper-router               1/1     1            1           62m
deployment.apps/skupper-service-controller   1/1     1            1           62m

NAME                                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)               AGE
service/skupper                          ClusterIP   10.217.5.53    <none>        8080/TCP,8081/TCP     62m
service/skupper-redis-on-prem-server-0   ClusterIP   10.217.4.139   <none>        6379/TCP,26379/TCP    51m
service/skupper-redis-server-1           ClusterIP   10.217.5.141   <none>        6379/TCP,26379/TCP    6s
service/skupper-router                   ClusterIP   10.217.5.84    <none>        55671/TCP,45671/TCP   62m
service/skupper-router-local             ClusterIP   10.217.5.56    <none>        5671/TCP              62m
```

Take a moment to view the network configuration in RHAI:
```
ON-PREM: yaml$ skupper network status
Sites:
╰─ [local] 5d1dc1b - local 
   URL: skupper-inter-router-redis-demo.apps-crc.testing
   mode: interior
   name: local
   namespace: redis-demo
   version: 1.0.2
   ╰─ Services:
      ├─ name: skupper-redis-on-prem-server-0
      │  address: skupper-redis-on-prem-server-0: 6379 26379
      │  protocol: tcp
      ╰─ name: skupper-redis-server-1
         address: skupper-redis-server-1: 6379 26379
         protocol: tcp
         ╰─ Targets:
            ├─ name: skupper-redis-server-1-6bb44b65b5-mfgbv
            ╰─ name: skupper-redis-server-1-6bb44b65b5-mfgbv
```

```
ON-PREM: yaml$ skupper gateway status
Gateway Definition:
╰─ rh-brbaker-bakerapps-net-bryon type:podman version:2.0.2
   ╰─ Bindings:
      ├─ skupper-redis-on-prem-server-0:6379 tcp skupper-redis-on-prem-server-0:6379 127.0.0.1 6379
      ╰─ skupper-redis-on-prem-server-0:26379 tcp skupper-redis-on-prem-server-0:26379 127.0.0.1 26379
ON-PREM: bryon@rh-brbaker-bakerapps-net:(main)yaml$ 
```

### Update the Application Client to use the new Cache Replica
```
$ oc edit cm/redis-reader-on-prem-app-config
```
Change the server address property to be: ```server-address=skupper-redis-server-1:6379```.    

```
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  app-config.properties: |
    server-address=skupper-redis-server-1:6379
    db-password=
    database=0
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"app-config.properties":"server-address=skupper-redis-on-prem-server-0.redis-demo.svc.cluster.local:6379\ndb-p>
  creationTimestamp: "2022-09-24T01:19:08Z"
  name: redis-reader-on-prem-app-config
  namespace: redis-demo
  resourceVersion: "833490"
  uid: e822134e-bd72-46d6-bc85-fa37a565e3e2
```
 Type Ctrl-X to save the file.

 We now need to force the running client to use the new replica. Delete the pod and wait for the new pod to spawn:
 ```
 ON-PREM: yaml$ oc get pods | grep redis-read
redis-read-tester-7c474855bb-zfzvx            1/1     Running   0          52m

ON-PREM: yaml$ oc delete pod/redis-read-tester-7c474855bb-zfzvx
pod "redis-read-tester-7c474855bb-zfzvx" deleted
ON-PREM: yaml$ oc get pods | grep redis-read
redis-read-tester-7c474855bb-czp42            1/1     Running   0          10s
```  
View the logs of the new read tester.

```
ON-PREM-yaml$ oc logs pod/redis-read-tester-7c474855bb-czp42

Loading configuration
map[database:0 db-password: server-address:skupper-redis-server-1:6379]
Redis connection:  Redis<skupper-redis-server-1:6379 db:0>
Context: context.Background
Redis Reader
ReadFromChache()
Result: {" key "}:{" protozoologist-unscalloped "}
Result: {" key "}:{" twice-pursued-frush "}
Result: {" key "}:{" twice-pursued-frush "}
```

Scroll to the top and observe that the cache server is now: ```skupper-redis-server-1```

View the RHAI Console and observe the Client Application's connection is no longer to the Master cache.

<img src="./images/rhai-on-prem-2.png" alt="drawing" width="800"/>

Open the ON-PREM terminal and attach to view the cache reader logs:
```
ON-PREM: yaml$ oc attach pod/redis-read-tester-7c474855bb-czp42
If you don't see a command prompt, try pressing enter.
Result: {" key "}:{" ventriloqual-zealotical "}
Result: {" key "}:{" ventriloqual-zealotical "}
Result: {" key "}:{" overforward-temporarily "}
```
Leave this running as you will use this to compare the global cache replication later.

The following screen shot shows the "Mainframe", the logs from the original fat-client on-premises Application Client, and the Application CLient using the replicated cache on On-Premises OpenShift. Observe how they are all in sync.

<img src="./images/rhai-on-prem-3.png" alt="drawing" width="800"/>


## Migrate the Cache and Application to the Public Cloud

### Story Arc
Now that your application is cloud native and cloud ready, you can start the cloud migration using the consistent fabric provided by OpenShift Fabric, and the seamless application interconnectivity provided by Red Hat Application Interconnect.

### Set up the Sydney Cloud Environment
Open a new terminal window and set up the Sydney environment:
```
src$ . ./scripts/env-setup-ibm.sh
SYDNEY: src$
```
Observe the prompt now indicates you are using the SYDNEY environment

```
SYDNEY src$ oc create-project redis-sydney
```

### Create the RHAI Network

```
SYDNEY: src$ skupper init --site-name SYDNEY --console-auth=internal --console-user=admin --console-password=password

Skupper is now installed in namespace 'redis-sydney'.  Use 'skupper status' to get more information.
```
Now you have installed RHAI you need to add the Sydney router to the RHAI network.

Create a secure token:
```
SYDNEY: src$ skupper token create --token-type cert ibm-cloud.yaml
Connection token written to sydney-token.yaml
```

This is the token that you need to securely deliver to the ON-PREM site and import into RHAI.

Change to the ON-PREM terminal and enter the following command to import the token and link the routers.

```
ON-PREM: src$ skupper link create sydney-token.yaml 

Site configured to link to skupper-inter-router-redis-sydney.violet-cluster-new-2761a99850dd8c23002378ac6ce7f9ad-0000.au-syd.containers.appdomain.cloud:443 (name=link1)
Check the status of the link using 'skupper link status'.
```

View the topology in the RHAI console:  

<img src="./images/rhai-syd-3.png" alt="drawing" width="800"/>

To view the network status type the command ```skupper network status```.

You need to wait while the routers are synchronising. But after a while the network should report as follows:

```
SYDNEY: src$ skupper network status

Sites:
├─ [local] d30741a - SYDNEY 
│  URL: skupper-inter-router-redis-sydney.violet-cluster-new-2761a99850dd8c23002378ac6ce7f9ad-0000.au-syd.containers.appdomain.cloud
│  mode: interior
│  name: SYDNEY
│  namespace: redis-sydney
│  version: 1.0.2
│  ╰─ Services:
│     ├─ name: skupper-redis-server-1
│     │  address: skupper-redis-server-1: 6379 26379
│     │  protocol: tcp
│     ╰─ name: skupper-redis-on-prem-server-0
│        address: skupper-redis-on-prem-server-0: 6379 26379
│        protocol: tcp
╰─ [remote] 5d1dc1b - local 
   name: local
   namespace: redis-demo
   sites linked to: d30741a-SYDNEY
   version: 1.0.2
   ╰─ Services:
      ├─ name: skupper-redis-server-1
      │  address: skupper-redis-server-1: 6379 26379
      │  protocol: tcp
      │  ╰─ Targets:
      │     ├─ name: skupper-redis-server-1-6bb44b65b5-9wt2q
      │     ╰─ name: skupper-redis-server-1-6bb44b65b5-9wt2q
      ╰─ name: skupper-redis-on-prem-server-0
         address: skupper-redis-on-prem-server-0: 6379 26379
         protocol: tcp
SYDNEY: bryon@rh-brbaker-bakerapps-net:(main)src$ 
```

When you established the network, RHAI made all of the remote services available to the Sydney-based cluster.

View the services and pods running in Sydney:
```
src$ oc get pods,svc

NAME                                              READY   STATUS    RESTARTS   AGE
pod/skupper-router-7d77d7d48c-dss9w               2/2     Running   0          13m
pod/skupper-service-controller-6d6d77b546-n6zcz   1/1     Running   0          13m

NAME                                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)               AGE
service/skupper                          ClusterIP   172.21.47.48     <none>        8080/TCP,8081/TCP     13m
service/skupper-redis-on-prem-server-0   ClusterIP   172.21.249.92    <none>        6379/TCP,26379/TCP    4m16s
service/skupper-redis-server-1           ClusterIP   172.21.114.89    <none>        6379/TCP,26379/TCP    4m15s
service/skupper-router                   ClusterIP   172.21.204.203   <none>        55671/TCP,45671/TCP   13m
service/skupper-router-local             ClusterIP   172.21.91.236    <none>        5671/TCP              13m
```

Observe that the only pods running are the skupper pods, but there are two redis services that you exposed with ```skupper expose``` earlier in this demonstration. The remote services are made available in the Sydney cluster via the RHAI router.  

**Note:** We could just deploy the application to Sydney and have it use the on-premises cache. But for this demonstration we create a replica in the cloud and use it locally.

### Deploy the cache to the Public Cloud

```
SYDNEY: src$ oc apply -f yaml/redis-ibm-ocp-dep.yaml 

deployment.apps/skupper-redis-syd-server-2 created
configmap/skupper-redis-syd-server-2 created
```

To quickly test if the cache is replicating, query the cache directly from within Redis running in Sydney

```
SYDNEY: src$ oc get pods | grep redis
NAME                                          READY   STATUS    RESTARTS   AGE
skupper-redis-syd-server-2-59658ddbb9-dp4zr   2/2     Running   0          65s

SYDNEY: src$ oc exec skupper-redis-syd-server-2-59658ddbb9-dp4zr -c redis -- redis-cli get key
quadrisyllabical-alabastra
```

Observe the cache value matches the most recent value written to the on-premises master cache by the "Mainframe."

We now need to make the Sydney replica available to the RHAI network:

```
src$ skupper expose deployment skupper-redis-syd-server-2  --port 6379,26379

deployment skupper-redis-syd-server-2 exposed as skupper-redis-syd-server-2

```

Examine the deployments, services, and running pods. Observe the Sydney replica is now available:
```
SYDNEY: src$ oc get deployment,svc,pods
NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/skupper-redis-syd-server-2   1/1     1            1           8m49s
deployment.apps/skupper-router               1/1     1            1           28m
deployment.apps/skupper-service-controller   1/1     1            1           28m

NAME                                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)               AGE
service/skupper                          ClusterIP   172.21.47.48     <none>        8080/TCP,8081/TCP     28m
service/skupper-redis-on-prem-server-0   ClusterIP   172.21.249.92    <none>        6379/TCP,26379/TCP    19m
service/skupper-redis-server-1           ClusterIP   172.21.114.89    <none>        6379/TCP,26379/TCP    19m
service/skupper-redis-syd-server-2       ClusterIP   172.21.188.102   <none>        6379/TCP,26379/TCP    22s
service/skupper-router                   ClusterIP   172.21.204.203   <none>        55671/TCP,45671/TCP   28m
service/skupper-router-local             ClusterIP   172.21.91.236    <none>        5671/TCP              28m

NAME                                              READY   STATUS    RESTARTS   AGE
pod/skupper-redis-syd-server-2-59658ddbb9-dp4zr   2/2     Running   0          8m49s
pod/skupper-router-7d77d7d48c-dss9w               2/2     Running   0          28m
pod/skupper-service-controller-6d6d77b546-n6zcz   1/1     Running   0          28m
```

Take a moment to examine the network configuration. Observe where the services reside versus where they are available.

```
src$ skupper network status
Sites:
├─ [local] d30741a - SYDNEY 
│  URL: skupper-inter-router-redis-sydney.violet-cluster-new-2761a99850dd8c23002378ac6ce7f9ad-0000.au-syd.containers.appdomain.cloud
│  mode: interior
│  name: SYDNEY
│  namespace: redis-sydney
│  version: 1.0.2
│  ╰─ Services:
│     ├─ name: skupper-redis-on-prem-server-0
│     │  address: skupper-redis-on-prem-server-0: 6379 26379
│     │  protocol: tcp
│     ├─ name: skupper-redis-server-1
│     │  address: skupper-redis-server-1: 6379 26379
│     │  protocol: tcp
│     ╰─ name: skupper-redis-syd-server-2
│        address: skupper-redis-syd-server-2: 6379 26379
│        protocol: tcp
│        ╰─ Targets:
│           ├─ name: skupper-redis-syd-server-2-59658ddbb9-dp4zr
│           ╰─ name: skupper-redis-syd-server-2-59658ddbb9-dp4zr
╰─ [remote] 5d1dc1b - local 
   name: local
   namespace: redis-demo
   sites linked to: d30741a-SYDNEY
   version: 1.0.2
   ╰─ Services:
      ├─ name: skupper-redis-on-prem-server-0
      │  address: skupper-redis-on-prem-server-0: 6379 26379
      │  protocol: tcp
      ├─ name: skupper-redis-server-1
      │  address: skupper-redis-server-1: 6379 26379
      │  protocol: tcp
      │  ╰─ Targets:
      │     ├─ name: skupper-redis-server-1-6bb44b65b5-9wt2q
      │     ╰─ name: skupper-redis-server-1-6bb44b65b5-9wt2q
      ╰─ name: skupper-redis-syd-server-2
         address: skupper-redis-syd-server-2: 6379 26379
         protocol: tcp
SYDNEY: bryon@rh-brbaker-bakerapps-net:(main)src$ 
```

View the topology in the RHAI Web Console.

<img src="./images/rhai-syd-2.png" alt="drawing" width="800"/>

<img src="./images/rhai-syd-1.png" alt="drawing" width="800"/>

### Deploy the Client Application to Sydney

```
SYDNEY: src$ oc apply -f yaml/redis-reader-sydney-dep.yaml 

configmap/redis-reader-app-config created
deployment.apps/redis-read-tester created
```

Check the reader is running and accessing the local cache.
Observe the ```server-address``` is the replica located in Sydney.

```
SYDNEY: src$ oc get pods | grep read

redis-read-tester-59c5857b77-l7xkp            1/1     Running   0          7s

SYDNEY: src$ oc logs pod/redis-read-tester-59c5857b77-l7xkp

Loading configuration
map[database:0 db-password: server-address:skupper-redis-syd-server-2.redis-sydney.svc.cluster.local:6379]
Reddis connection:  Redis<skupper-redis-syd-server-2.redis-sydney.svc.cluster.local:6379 db:0>
Context: context.Background
Redis Reader
ReadFromChache()
Result: {" key "}:{" kingmaking-leisured "}
Result: {" key "}:{" kingmaking-leisured "}
Result: {" key "}:{" peregrinate-tirr "}
Result: {" key "}:{" peregrinate-tirr "}
Result: {" key "}:{" chalumeau-Cyrenaic "}
```

### Story Arc
You have now successfully set up a Redis cache that is replicated from on-premises into the public cloud. This is a common pattern that is used to protect core systems from Internet-scale workloads.

## Create Replicas in London and New York

### Story Arc
With RHAI you can easily extend the application's network across all compute locations. In this case we will add London and New York.

As previously discussed, this is a very complex task to do with Redis on Kubernetes. You would typically require a dedicated network and use Submariner to link Kubernetes Clusters, Service Mesh with Federation, or Node Ports. All these options add complexity, security exposure, and management overhead.

### Deploy RHAI in London and New York

#### London
```
LONDON: src$ oc new-project redis-london
Now using project "redis-london" on server "https://c100-e.au-syd.containers.cloud.ibm.com:31734".

LONDON: src$ skupper init --site-name LONDON --console-auth=internal --console-user=admin --console-password=password

Skupper is now installed in namespace 'redis-london'.  Use 'skupper status' to get more information.

LONDON: src$ skupper token create --token-type cert london-token.yaml

Connection token written to london-token.yaml

```

#### New York
```
oc new-project redis-nyc

Now using project "redis-nyc" on server "https://c100-e.au-syd.containers.cloud.ibm.com:31734".


NEW-YORK: src$ skupper init --site-name NEW-YORK --console-auth=internal --console-user=admin --console-password=password

Skupper is now installed in namespace 'redis-nyc'.  Use 'skupper status' to get more information.

NEW-YORK: src$ skupper token create --token-type cert nyc-token.yaml

Connection token written to nyc-token.yaml 
```

### On Premises OpenShift Cluster
Import the tokens

```
ON-PREM: src$ skupper link create london-token.yaml 

Site configured to link to skupper-inter-router-redis-london.violet-cluster-new-2761a99850dd8c23002378ac6ce7f9ad-0000.au-syd.containers.appdomain.cloud:443 (name=link2)
Check the status of the link using 'skupper link status'.

ON-PREM: src$ skupper link create nyc-token.yaml 

Site configured to link to skupper-inter-router-redis-nyc.violet-cluster-new-2761a99850dd8c23002378ac6ce7f9ad-0000.au-syd.containers.appdomain.cloud:443 (name=link3)
Check the status of the link using 'skupper link status'.
```

View the network in the console. Observe that all routes go via the On Premises cluster.

<img src="./images/rhai-global-1.png" alt="drawing" width="800"/>

Let's turn this into a multi-path mesh network.

Using instructions from earlier in this lab:  
1. Export tokens from London and Sydney.
2. Import the tokens into the New York RHAI.

Observe the results in the RHAI console:  

<img src="./images/rhai-global-2.png" alt="drawing" width="800"/>

You have now created redundant paths for the RHAI network.

## Deploy the Cache Replicas

### London
```
LONDON: src$ oc apply -f yaml/redis-london-ocp-dep.yaml 
deployment.apps/skupper-redis-london-server-3 created
configmap/skupper-redis-london-server-3 created

LONDON: src$ oc get pod | grep london
skupper-redis-london-server-3-55cfc585d6-bxw5p   2/2     Running   0          26s

LONDON: src$ oc exec skupper-redis-london-server-3-55cfc585d6-bxw5p -c redis -- redis-cli get key
wariest-cannon-proof

LONDON: src$ skupper expose deployment skupper-redis-london-server-3 --port 6379,26379

deployment skupper-redis-london-server-3 exposed as skupper-redis-london-server-3
```

### New York
```
src$ oc apply -f yaml/redis-new-york-ocp-dep.yaml 
deployment.apps/skupper-redis-nyc-server-4 created
configmap/skupper-redis-nyc-server-4 created

NEW-YORK: src$ oc get pod | grep nyc
skupper-redis-nyc-server-4-854bb7f8f-jwd22    2/2     Running   0          11s

NEW-YORK: bryonsrc$ oc exec skupper-redis-nyc-server-4-854bb7f8f-jwd22 -c redis -- redis-cli get key
winetaster-horsfordite

NEW-YORK: src$ skupper expose deployment skupper-redis-nyc-server-4 --port 6379,26379
deployment skupper-redis-nyc-server-4 exposed as skupper-redis-nyc-server-4
```

Observe the network in the RHAI console  

<img src="./images/rhai-global-3.png" alt="drawing" width="800"/>

## Deploy the Application Clients to London and New York

### London

Deploy the client:
```
LONDON: src$ oc apply -f yaml/redis-reader-london-dep.yaml 
configmap/redis-reader-app-config created
deployment.apps/redis-read-tester created

LONDON: src$ oc get pod | grep read
redis-read-tester-59c5857b77-6r5mn               1/1     Running   0          9s
```

Observe the cache replic used by the London client application.  

```
LONDON: src$ oc logs redis-read-tester-59c5857b77-6r5mn
Loading configuration
map[database:0 db-password: server-address:skupper-redis-london-server-3.redis-london.svc.cluster.local:6379]
Reddis connection:  Redis<skupper-redis-london-server-3.redis-london.svc.cluster.local:6379 db:0>
Context: context.Background
Redis Reader
ReadFromChache()
Result: {" key "}:{" unfazed-macroplankton "}
Result: {" key "}:{" unfazed-macroplankton "}
Result: {" key "}:{" freewheelers-pamplegia "}
Result: {" key "}:{" freewheelers-pamplegia "}
Result: {" key "}:{" freewheelers-pamplegia "}
```

### New York

```
NEW-YORK: src$ oc apply -f yaml/redis-reader-nyc-dep.yaml 
configmap/redis-reader-app-config created
deployment.apps/redis-read-tester created

NEW-YORK: src$ oc get pod | grep read
redis-read-tester-59c5857b77-bn82d            1/1     Running   0          3s

NEW-YORK: src$ oc logs redis-read-tester-59c5857b77-bn82d
Loading configuration
map[database:0 db-password: server-address:skupper-redis-nyc-server-4.redis-nyc.svc.cluster.local:6379]
Reddis connection:  Redis<skupper-redis-nyc-server-4.redis-nyc.svc.cluster.local:6379 db:0>
Context: context.Background
Redis Reader
ReadFromChache()
Result: {" key "}:{" gesticulative-frillily "}
Result: {" key "}:{" diastalsis-nondehiscent "}
Result: {" key "}:{" diastalsis-nondehiscent "}
Result: {" key "}:{" hylodes-anticreativeness "}
Result: {" key "}:{" hylodes-anticreativeness "}
```


Observe the network in the RHAI console.  
**Note:** The console has a bug and not all redis-read-tester apps are displayed.  

<img src="./images/rhai-global-4.png" alt="drawing" width="800"/>

## Conclusion

```
LONDON: src$ oc attach pod/redis-read-tester-59c5857b77-6r5mn

If you don't see a command prompt, try pressing enter.
Result: {" key "}:{" stagyrite-pashalics "}
Result: {" key "}:{" overdomesticate-thermionic "}
Result: {" key "}:{" overdomesticate-thermionic "}
Result: {" key "}:{" overestimated-pyrolyzing "}
```

```
NEW-YORK: oc attach redis-read-tester-59c5857b77-bn82d

If you don't see a command prompt, try pressing enter.
Result: {" key "}:{" chamar-unsoldering "}
Result: {" key "}:{" thym--Boshas "}
Result: {" key "}:{" thym--Boshas "}
Result: {" key "}:{" tunicin-encoffin "}
Result: {" key "}:{" tunicin-encoffin "}
Result: {" key "}:{" reapproving-metalised "}
```

Merge all the terminals from each site into a single console display. Here you can see the "mainframe" writing to the cache and that cache being consumed on premises, and via replicas located: on-premises, Sydney, New York, and London.  

<img src="./images/rhai-finished.gif" alt="drawing"/>
