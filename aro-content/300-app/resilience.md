In this section of the workshop, we will deploy an application to an ARO cluster, ensure the application is resilient to node failure, and scale the application when under load.

## Deploy an application

1. First, let's deploy an application. To do so, run the following set of commands:

    ```bash
    oc new-project resilience-ex
    oc -n resilience-ex new-app https://github.com/sohaibazed/frontend-js.git --name frontend-js
    oc -n resilience-ex expose svc frontend-js
    oc -n resilience-ex set resources deployment/frontend-js \
      --limits=cpu=60m,memory=150Mi \
      --requests=cpu=50m,memory=100Mi
    ```

1. While the application is being built from source, you can watch the rollout status of the deployment object to see when its finished.

    ```bash
    oc rollout status deploy/frontend-js
    ```

1. We can now use the route to view the application in your web browser. To get the route, run the following command:

    ```bash
    oc -n resilience-ex get route frontend-js \
      -o jsonpath='http://{.spec.host}{"\n"}'
    ```

    Then visit the URL presented in a new tab in your web browser (using HTTP). For example, your output will look something similar to:

    ```bash
    frontend-js-resilience-ex.apps.ce7l3kf6.eastus.aroapp.io
    ```

    In that case, you'd visit `http://frontend-js-resilience-ex.apps.ce7l3kf6.eastus.aroapp.io` in your browser.

1. Initially, this application is deployed with only one pod. In the event a worker node goes down or the pod crashes, there will be an outage of the application. To prevent that, let's scale the number of instances of our applications up to three. To do so, run the following command:

    ```bash
    oc -n resilience-ex scale deployment \
      frontend-js --replicas=3
    ```

1. Next, check to see that the application has scaled. To do so, run the following command to see the pods.
Then check that it has scaled

    ```bash
    oc -n resilience-ex get pods \
      -l deployment=frontend-js
    ```

    Your output should look similar to this:

    ```bash
    NAME                           READY   STATUS      RESTARTS   AGE
    frontend-js-7cdc846c94-5mrk8   1/1     Running     0          3m45s
    frontend-js-7cdc846c94-bj4wq   1/1     Running     0          3m45s
    frontend-js-7cdc846c94-gjxv6   1/1     Running     0          4m39s
    ```

## Pod Disruption Budget

A Pod disruption Budget (PBD) allows you to limit the disruption to your application when its pods need to be rescheduled for upgrades or routine maintenance work on ARO nodes. In essence, it lets developers define the minimum tolerable operational requirements for a deployment so that it remains stable even during a disruption.

For example, frontend-js deployed as part of the last step contains three replicas distributed evenly across three nodes. We can tolerate losing two pods but not one, so we create a PDB that requires a minimum of one replica.

A PodDisruptionBudget object’s configuration consists of the following key parts:

- A label selector, which is a label query over a set of pods.
- An availability level, which specifies the minimum number of pods that must be available simultaneously, either:
  - minAvailable is the number of pods must always be available, even during a disruption.
  - maxUnavailable is the number of pods can be unavailable during a disruption.

!!! danger
    A maxUnavailable of 0% or 0 or a minAvailable of 100% or equal to the number of replicas can be used but will block nodes from being drained and can result in application instability during maintenance activities.

1. Let's create a Pod Disruption Budget for our `frontend-js` application. To do so, run the following command:

    ```bash
    cat <<EOF | oc apply -f -
    apiVersion: policy/v1
    kind: PodDisruptionBudget
    metadata:
      name: frontend-js-pdb
      namespace: resilience-ex
    spec:
      minAvailable: 1
      selector:
        matchLabels:
          deployment: frontend-js
    EOF
    ```

    After creating the PDB, OpenShift API will ensure at least one pod of `frontend-js` is running all the time, even when maintenance is going on with the cluster.

1. Next, let's check the status of Pod Disruption Budget. To do so, run the following command:

    ```bash
    oc -n resilience-ex get poddisruptionbudgets
    ```

    Your output should match this:

    ```{.text .no-copy}
    NAME              MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
    frontend-js-pdb   1               N/A               2                     7m39s
    ```

## Horizontal Pod Autoscaler (HPA)

As a developer, you can use a horizontal pod autoscaler (HPA) to specify how Azure Red Hat OpenShift clusters should automatically increase or decrease the scale of a replication controller or deployment configuration, based on metrics collected from the pods that belong to that replication controller or deployment configuration. You can create an HPA for any any deployment, replica set, replication controller, or stateful set.

In this exercise we will scale the `frontend-js` application based on CPU utilization:

* Scale out when average CPU utilization is greater than 50% of CPU limit
* Maximum pods is 4
* Scale down to min replicas if utilization is lower than threshold for 60 sec

1. First, we should create the HorizontalPodAutoscaler. To do so, run the following command:

    ```
    cat <<EOF | oc apply -f -
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    metadata:
      name: frontend-js-cpu
      namespace: resilience-ex
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

1. Next, check the status of the HPA. To do so, run the following command:

    ```bash
    oc -n resilience-ex get horizontalpodautoscaler/frontend-js-cpu
    ```

    Your output should match the following:

    ```{.txt .no-copy}
    NAME              REFERENCE                TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
    frontend-js-cpu   Deployment/frontend-js   0%/50%   2         4         3          45s
    ```

1. Next, let's generate some load against the `frontend-js` application. To do so, run the following command:

    ```
    FRONTEND_URL=http://$(oc -n resilience-ex get route frontend-js -o jsonpath='{.spec.host}')
    siege -c 60 $FRONTEND_URL
    ```


1. Wait for a minute and then kill the siege command (by hitting CTRL and c on your keyboard). Then immediately check the status of Horizontal Pod Autoscaler. To do so, run the following command:

    ```bash
    oc -n resilience-ex get horizontalpodautoscaler/frontend-js-cpu
    ```

    Your output should look similar to this:

    ```{.text .no-copy}
    NAME              REFERENCE                TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
    frontend-js-cpu   Deployment/frontend-js   113%/50%   2         4         4          3m13s
    ```

    This means you are now running 4 replicas, instead of the original three that we started with.


1. Once you've killed the seige command, the traffic going to `frontend-js` service will cool down and after a 60 second cool down period, your application's replica count will drop back down to two. To demonstrate this, run the following command:

    ```bash
    oc -n resilience-ex get horizontalpodautoscaler/frontend-js-cpu --watch
    ```

    After a minute or two, your output should be similar to this:

    ```bash
    NAME              REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
    frontend-js-cpu   Deployment/frontend-js   10%/50%   2         4         4          6m55s
    frontend-js-cpu   Deployment/frontend-js   8%/50%    2         4         4          7m1s
    frontend-js-cpu   Deployment/frontend-js   8%/50%    2         4         3          7m16s
    frontend-js-cpu   Deployment/frontend-js   0%/50%    2         4         2          7m31s
    ```
