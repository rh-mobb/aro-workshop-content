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
oc new-app https://github.com/sohaibazed/frontend-js.git
oc expose svc frontend-js
oc set resources deployment/frontend-js \
   --limits=cpu=50m,memory=100Mi \
   --requests=cpu=60m,memory=150Mi
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

Right now the application is deployed inside one pod, and in case the worker running the pod crashes, the ReplicaSet object will recreate the pod on another node. You can scale the application to run on multiple pods using the following command

```bash
oc scale deployment frontend-js --replicas=2
deployment.apps/frontend-js scaled

oc get pod
NAME                           READY   STATUS      RESTARTS   AGE
frontend-js-1-build            0/1     Completed   0          5m7s
frontend-js-7dd7d46854-2xc9d   1/1     Running     0          3m48s
frontend-js-7dd7d46854-8r2fb   1/1     Running     0          24s
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
  minReplicas: 1
  maxReplicas: 3
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
```

Generate load using siege. 
```
FRONTEND_URL=http://$(oc get route frontend-js -n frontend-js -o jsonpath='{.spec.host}')
siege -c 40 $FRONTEND_URL
```

wait for a minute and check the status of Horizontal Pod Autoscaler. Your app should scale up to 3 replicas by now. 

