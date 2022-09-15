# Make Application Resilient 
In this section of the workshop, we will deploy an application to an ARO cluster, Ensure the application is resilient to node failure and scale when under load.


## Prerequisites
* a private ARO cluster
* oc cli
<br>


You will need to use the provided Virtual Machine to build and deploy the application.  This VM has the following required CLIs and development environment already installed:
* az cli
* oc cli
* siege (yum install siege -y)

## Deploy an application
Let's deploy an application!  

We will be deploying a JavaScript based application called [frontend-js](https://github.com/sohaibazed/frontend-js.git). This application will run on OpenShift and will be deployed as a Deployment object. The Deployment object creates ReplicaSet and ReplicaSet creates and manages pods.

Deploy the application
```bash
oc new-project frontend-js
oc new-app https://github.com/sohaibazed/frontend-js.git --name frontend-js
oc expose svc frontend-js
oc set resources deployment/frontend-js \
   --limits=cpu=60m,memory=150Mi \
   --requests=cpu=50m,memory=100Mi
```

Wait a couple of minutes for the application to deploy and then run ```oc get route -n frontend-js``` command to get the URL to access the app.

you can run the following command to check the deployment object
```bash
oc get deployment
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
frontend-js   0/1     0            0           59s
```

The following command will list the ReplicaSet object
```bash
oc get rs
NAME                     DESIRED   CURRENT   READY   AGE
frontend-js-7dd7d46854   1         1         1       58s
```

Right now the application is deployed inside one pod, and in case the worker running the pod crashes, the ReplicaSet object will register that the pod is down and recreate it on another node. You can scale the application to run on multiple pods using the following command

```bash
oc scale deployment frontend-js --replicas=3
deployment.apps/frontend-js scaled

oc get pod
NAME                           READY   STATUS      RESTARTS   AGE
frontend-js-1-build            0/1     Completed   0          5m7s
frontend-js-7cdc846c94-5mrk8   1/1     Running     0          3m45s
frontend-js-7cdc846c94-bj4wq   1/1     Running     0          3m45s
frontend-js-7cdc846c94-gjxv6   1/1     Running     0          4m39s
```

## Pod Disruption Budget
A Pod disruption Budget (PBD) allows you to limit the disruption to your application when its pods need to be rescheduled for upgrades or routine maintenance work on ARO nodes. In essence, it lets developers define the minimum tolerable operational requirements for a Deployment so that it remains stable even during a disruption. 

For example, frontend-js deployed as part of the last step contains two replicas distributed evenly across two nodes. We can tolerate losing one pods but not two, so we create a PDB that requires a minimum of two replicas.

A PodDisruptionBudget object’s configuration consists of the following key parts:
* A label selector, which is a label query over a set of pods.
* An availability level, which specifies the minimum number of pods that must be available simultaneously, either:
  * minAvailable is the number of pods must always be available, even during a disruption.
  * maxUnavailable is the number of pods can be unavailable during a disruption.


**NOTE** A maxUnavailable of 0% or 0 or a minAvailable of 100% or equal to the number of replicas is permitted but can block nodes from being drained.


Create PBD.yaml file with the following yaml.
```
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-js-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      deployment: frontend-js
```

Create PDB object
```
oc apply -f pdb.yaml
poddisruptionbudget.policy/frontend-js-pdb created
```

After creating PDB, OpenShift API will ensure two pods of ```frontend-js``` is running all the time while cluster is going through upgrade.

Check the status of PBD
```
oc get poddisruptionbudgets
NAME              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
frontend-js-pdb   2               N/A               1                     7m39s

```
## Horizontal Pod Autoscaler (HPA)

As a developer, you can use a horizontal pod autoscaler (HPA) to specify how OpenShift Container Platform should automatically increase or decrease the scale of a replication controller or deployment configuration, based on metrics collected from the pods that belong to that replication controller or deployment configuration. You can create an HPA for any any deployment, deployment config, replica set, replication controller, or stateful set.

In this exercise we will scale frontend application based on CPU utilization
* Scale out when average CPU utilization is greater than 80% of CPU limit
* Maximum pods is 5
* Scale down to min replicas if utilization is lower than threshold for 60 sec

```
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-js-cpu
  namespace: frontend-js
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend-js
  minReplicas: 2
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 50
          type: Utilization
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15

```

create CPU HPA for frontend-js app 
```
oc create -f frontend-js-cpu-hpa.yaml -n frontend-js
```

Check HPA status
```
watch oc get horizontalpodautoscaler/frontend-js-cpu -n frontend-js
NAME              REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
frontend-js-cpu   Deployment/frontend-js   0%/50%    2         4         2          33s
```

Generate load using siege. 
```
FRONTEND_URL=http://$(oc get route frontend-js -n frontend-js -o jsonpath='{.spec.host}')
siege -c 60 $FRONTEND_URL
```

wait for a minute and check the status of Horizontal Pod Autoscaler. Your app should scale up to more then two replicas by now. 

```
watch oc get horizontalpodautoscaler/frontend-js-cpu -n frontend-js
NAME              REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
frontend-js-cpu   Deployment/frontend-js   118%/50%   2         4         4          7m26s
```