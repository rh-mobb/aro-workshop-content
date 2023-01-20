## Introduction

Applications running on Azure Red Hat OpenShift (ARO) often use other Azure services including databases, caching, message queues, and storage. Using ASO, these services can be managed directly inside the cluster. In this task we will deploy an Azure Cache for Redis that can be used by an application running on OpenShift. [Azure Cache for Redis](https://azure.microsoft.com/en-us/products/cache/){:target="_blank"} is a fully managed, in-memory cache that enables high-performance and scalable architectures.

The voting app that will be deployed consists of a front end web-app that uses an Azure Cache for Redis instance to provide persistence of votes received for Cats and Dogs. The application interface has been built using Python and Flask.

## Deploy an Azure Cache for Redis instance

1. First, let's create a namespace (also known as a project in OpenShift). To do so, run the following command:

    ```bash
    oc new-project redis-ex
    ```

1. Next, let's inherit our existing Azure Resource Group to hold Azure resources that we create with ASO. To do so, run the following commmand:

    ```yaml
    cat <<EOF | oc apply -f -
    apiVersion: resources.azure.com/v1beta20200601
    kind: ResourceGroup
    metadata:
      name: "${AZ_RG}"
      namespace: redis-ex
      annotations:
        serviceoperator.azure.com/reconcile-policy: skip
    spec:
      location: eastus
    EOF
    ```

1. Let's verify that our Azure Resource Group has been successfully inherited. To do so, run the following command:

    ```bash
    oc get resourcegroup.resources.azure.com/${AZ_RG}
    ```

    You should receive output that shows your resource group is *Ready* and *Succeeded*, similar to this:

    ```bash
    NAME       READY   REASON      MESSAGE
    user1-rg   True    Succeeded
    ```

1. Next, we need to deploy the Redis cache itself. To do so, run the following command:

    ```yaml
    cat <<EOF | oc apply -f -
    apiVersion: cache.azure.com/v1beta20201201
    kind: Redis
    metadata:
      name: redis-${UNIQUE}
      namespace: redis-ex
    spec:
      location: eastus
      owner:
        name: "${AZ_RG}"
      sku:
        family: C
        name: Basic
        capacity: 0
      enableNonSslPort: true
      redisConfiguration:
        maxmemory-delta: "10"
        maxmemory-policy: allkeys-lru
      redisVersion: "6"
      operatorSpec:
        secrets:
          primaryKey:
            name: redis-secret
            key: primaryKey
          secondaryKey:
            name: redis-secret
            key: secondaryKey
          hostName:
            name: redis-secret
            key: hostName
          port:
            name: redis-secret
            key: port
    EOF
    ```

    This will take a few minutes to complete (sometimes up to 10 minutes). It is not unusual for there to be a lab between a resource being created in ASO and showing up in the Azure Portal.

1. To monitor the creation process, run the following command:

    ```bash
    watch ~/bin/oc -n redis-ex get redis
    ```

    Your output will look like this:

    ```bash
    NAME             READY   SEVERITY   REASON        MESSAGE
    redis-3686       False   Info       Reconciling   The resource is in the process of being reconciled by the operator
    ```

    Eventually, the result will show:

    ```bash
    NAME             READY   SEVERITY   REASON      MESSAGE
    redis-3686       True               Succeeded
    ```

    !!! info

        Watch will refresh the output of a command every second. Hit CTRL and c on your keyboard to exit the watch command when you're ready to move on to the next part of the workshop.


1. (Optional) If you'd like to monitor the creation of the resource in the Azure Portal, you can search for "Redis" in the search bar.

    ![Azure Portal - Redis Search](/assets/images/azure-portal-redis-search.png)

    Once the Redis instance has successfully deployed, you can move on to deploying the voting app.

### Deploy the voting app

The Azure Voting App will be deployed from a pre-built container that is stored in the public Microsoft Azure Container Registry. It's environment variables are configured to use the URL of the Redis cache deployed in the last step, and a Kubernetes Secret that was created as part of the cache deployment.

1. Next, let's deploy our application and associated resources that will use our newly created Redis instance. To do so, run the following command:

    ```yaml
    cat <<EOF | oc apply -f -
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: azure-vote-front
      namespace: redis-ex
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: azure-vote-front
      template:
        metadata:
          labels:
            app: azure-vote-front
        spec:
          containers:
          - name: azure-vote-front
            image: aroworkshop.azurecr.io/azure-vote:latest
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 250m
                memory: 256Mi
            ports:
            - containerPort: 8080
            env:
            - name: REDIS
              valueFrom:
                secretKeyRef:
                  name: redis-secret
                  key: hostName
            - name: REDIS_NAME
              value: "redis-${UNIQUE}"
            - name: REDIS_PWD
              valueFrom:
                secretKeyRef:
                  name: redis-secret
                  key: primaryKey
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: azure-vote-front
      namespace: redis-ex
    spec:
      ports:
      - port: 8080
        targetPort: 8080
      selector:
        app: azure-vote-front
    ---
    apiVersion: route.openshift.io/v1
    kind: Route
    metadata:
      name: azure-vote
      namespace: redis-ex
    spec:
      port:
        targetPort: 8080
      to:
        kind: Service
        name: azure-vote-front
        weight: 100
      tls:
        insecureEdgeTerminationPolicy: Redirect
        termination: edge
      wildcardPolicy: None
    EOF
    ```

1. Next, let's validate that the application has been deployed. To do so, run the following command:

    ```bash
    oc -n redis-ex get pod -l app=azure-vote-front
    ```

    Your output will look something like this:

    ```bash
    NAME                                READY   STATUS    RESTARTS   AGE
    azure-vote-front-6b78d59df4-hbtkt   1/1     Running   0          2m4s
    ```

    Once you see "1/1" and "Running", the application is available to access.

1. And finally, view the voting app in your browser. To do so, get the route of your application by running the following command:

```bash
oc -n redis-ex get route azure-vote -o jsonpath='{.spec.host}'
```

Then visit the URL presented in a new tab in your web browser (using HTTPS). For example, your output will look something similar to:

```bash
azure-vote-redis-ex.apps.ce7l3kf6.eastus.aroapp.io
```

In that case, you'd visit `https://azure-vote-redis-ex.apps.ce7l3kf6.eastus.aroapp.io` in your browser.

Congratulations! You've successfully demonstrated the ability to deploy Azure resources using ASO and use those resources with applications on your ARO cluster.
