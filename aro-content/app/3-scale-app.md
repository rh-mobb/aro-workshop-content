# Make Application Resilient

In this section of the workshop, we will deploy an application to an ARO cluster, Ensure the application is resilient to node failure and scale when under load.

## Deploy an application

Let's deploy an application!

We will be deploying a JavaScript based application called [frontend-js](https://github.com/sohaibazed/frontend-js.git). This application will run on OpenShift and will be deployed as a Deployment object. The Deployment object creates ReplicaSet and ReplicaSet creates and manages pods.

Deploy the application
```bash
cd ~
oc new-project frontend-js
oc new-app https://github.com/sohaibazed/frontend-js.git --name frontend-js
oc expose svc frontend-js
oc set resources deployment/frontend-js \
   --limits=cpu=60m,memory=150Mi \
   --requests=cpu=50m,memory=100Mi
```

The application is being built from source, you can watch the Deployment object to see when its finished.

```bash
watch ~/bin/oc get deployment
```

Eventually the Deployment will be Ready.

```{.text .no-copy}
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
frontend-js   1/1     0            0           59s
```

You can now get the route and open it in your browser to ensure that its working.

```bash
oc get route -n frontend-js
```

```{.text .no-copy}
NAME          HOST/PORT                                                           PATH   SERVICES      PORT       TERMINATION   WILDCARD
frontend-js   frontend-js-frontend-js.apps.hkngv2cf.eastus.aroapp.io ... 1 more          frontend-js   8080-tcp
```

!!! warning
    By default the route does not use TLS, so access the route with **http://frontend-js-frontend-js.apps...**

Right now the application is deployed inside one pod, and in case the worker running the pod crashes, the ReplicaSet object will register that the pod is down and recreate it on another node. You can scale the application to run on multiple pods using the following command

```bash
oc scale deployment frontend-js --replicas=3
```

Then check that it has scaled

```bash
oc get pods -l deployment=frontend-js
```

```{.text .no-copy}
NAME                           READY   STATUS      RESTARTS   AGE
frontend-js-7cdc846c94-5mrk8   1/1     Running     0          3m45s
frontend-js-7cdc846c94-bj4wq   1/1     Running     0          3m45s
frontend-js-7cdc846c94-gjxv6   1/1     Running     0          4m39s
```

## Pod Disruption Budget
A Pod disruption Budget (PBD) allows you to limit the disruption to your application when its pods need to be rescheduled for upgrades or routine maintenance work on ARO nodes. In essence, it lets developers define the minimum tolerable operational requirements for a Deployment so that it remains stable even during a disruption.

For example, frontend-js deployed as part of the last step contains two replicas distributed evenly across two nodes. We can tolerate losing one pods but not two, so we create a PDB that requires a minimum of two replicas.

A PodDisruptionBudget object’s configuration consists of the following key partsi:

- A label selector, which is a label query over a set of pods.
- An availability level, which specifies the minimum number of pods that must be available simultaneously, either:
  - minAvailable is the number of pods must always be available, even during a disruption.
  - maxUnavailable is the number of pods can be unavailable during a disruption.


!!! note
    A maxUnavailable of 0% or 0 or a minAvailable of 100% or equal to the number of replicas is permitted but can block nodes from being drained.


Create a Pod Disruption Budget

```bash
cat <<EOF | oc apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-js-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      deployment: frontend-js
EOF
```

After creating PDB, OpenShift API will ensure two pods of ```frontend-js``` is running all the time while cluster is going through upgrade.

Check the status of PBD

```bash
oc get poddisruptionbudgets
```

```{.text .no-copy}
NAME              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
frontend-js-pdb   2               N/A               1                     7m39s
```
## Horizontal Pod Autoscaler (HPA)

As a developer, you can use a horizontal pod autoscaler (HPA) to specify how OpenShift Container Platform should automatically increase or decrease the scale of a replication controller or deployment configuration, based on metrics collected from the pods that belong to that replication controller or deployment configuration. You can create an HPA for any any deployment, deployment config, replica set, replication controller, or stateful set.

In this exercise we will scale frontend application based on CPU utilization:

* Scale out when average CPU utilization is greater than 50% of CPU limit
* Maximum pods is 4
* Scale down to min replicas if utilization is lower than threshold for 60 sec

```
cat <<EOF | oc apply -f -
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
EOF
```

Check HPA status

```bash
oc get horizontalpodautoscaler/frontend-js-cpu -n frontend-js
```

```{.text .no-copy}
NAME              REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
frontend-js-cpu   Deployment/frontend-js   0%/50%    2         4         2          33s
```

Generate load using siege.

```
FRONTEND_URL=http://$(oc get route frontend-js -n frontend-js -o jsonpath='{.spec.host}')
siege -c 60 $FRONTEND_URL
```

wait for a minute and then kill the siege command (CTRL-C) and check the status of Horizontal Pod Autoscaler. Your app should have scaled up to more then two replicas by now.

```bash
oc get horizontalpodautoscaler/frontend-js-cpu -n frontend-js
```

```{.text .no-copy}
NAME              REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
frontend-js-cpu   Deployment/frontend-js   118%/50%   2         4         4          7m26s
```

After you kill/stop the seige command, the traffic going to frontend-js service will cool down and after a 60sec cool down period you will see the replica count going back down to two.

```bash
oc get horizontalpodautoscaler/frontend-js-cpu -n frontend-js
```

```{.text .no-copy}
NAME              REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
frontend-js-cpu   Deployment/frontend-js   0%/50%   2         4         2          7m26s
```
