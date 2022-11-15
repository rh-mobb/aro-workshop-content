## Introduction

Labels are a useful way to select which nodes that an application will run on. These nodes are created by machines which are defined by the MachineSets we worked with in previous sections of this workshop. An example of this would be running a memory intensive application only on a specific node type.

While you can directly add a label to a node, it is not recommended because nodes can be recreated, which would cause the label to disappear. Therefore we need to label the MachineSet itself. An important caveat to this process is that only **new machines** created by the MachineSet will get the label. This means you will need to either scale the MachineSet down to zero then back up to create new machines with the label, or you can label the existing machines directly.

## Set a label for the MachineSet

1. Just like the last section, let's pick a MachineSet to add our label. To do so, run the following command:

    ```bash
    MACHINESET=$(oc -n openshift-machine-api get machinesets -o name | head -1)
    echo ${MACHINESET}
    ```

1. Now, let's patch the MachineSet with our new label. To do so, run the following command:

    ```bash
    oc -n openshift-machine-api patch ${MACHINESET} --type=merge -p '{"spec":{"template":{"spec":{"metadata":{"labels":{"tier":"frontend"}}}}}}'
    ```

1. As you'll remember, the existing machines won't get this label, but all new machines will. While we could just scale this MachineSet down to zero and back up again, that could disrupt our workloads. Instead, let's just loop through and add the label to all of our nodes in that MachineSet. To do so, run the following command: 

    ```bash
    MACHINES=$(oc -n openshift-machine-api get machines -o name -l "machine.openshift.io/cluster-api-machineset=$(echo $MACHINESET | cut -d / -f2 )" | xargs)
    oc label -n openshift-machine-api ${MACHINES} tier=frontend
    NODES=$(echo $MACHINES | sed 's/machine.machine.openshift.io/node/g')
    oc label ${NODES} tier=frontend
    ```

    !!! info

        Just like MachineSets, machines do not automatically label their existing child resources, this means we need to relabel them ourselves to avoid having to recreate them.

1. Now, let's verify the nodes are properly labeled. To do so, run the following command:

    ```bash
    oc get nodes --selector='tier=frontend'
    ```

    Your output will look something like this:

    ```bash
    NAME                                       STATUS   ROLES    AGE     VERSION
    user1-cluster-8kvh4-worker-eastus1-hd5cw   Ready    worker   7h31m   v1.23.5+3afdacb
    user1-cluster-8kvh4-worker-eastus1-zj7dl   Ready    worker   7h22m   v1.23.5+3afdacb
    ```

    Pending that your output shows one or more node, this demonstrates that our MachineSet and associated nodes are properly annotated! 

## Deploy an app to the labeled nodes

Now that we've successfully labeled our nodes, let's deploy a workload to demonstrate app placement using `nodeSelector`. This should force our app to only our labeled nodes. 

1. First, let's create a namespace (also known as a project in OpenShift). To do so, run the following command:

    ```bash
    oc new-project nodeselector-ex
    ```

1. Next, let's deploy our application and associated resources that will target our labeled nodes. To do so, run the following command:

    ```bash
    oc create -f https://ws.mobb.cloud/assets/node-select-deployment.yaml
    ```

    !!! info "Wondering what we just created?"

        This is the app deployment and associated resource definition that will target our labeled worker nodes.

    ``` title="node-select-deployment.yaml"
    --8<-- "node-select-deployment.yaml"
    ```

1. Now, let's validate that the application has been deployed to one of the labeled nodes. To do so, run the following command:

    ```bash
    oc -n nodeselector-ex get pod -l app=nodeselector-app -o wide
    ```

    Your output will look something like this:

    ```bash
    NAME                                READY   STATUS    RESTARTS   AGE   IP            NODE                                       NOMINATED NODE   READINESS GATES
    nodeselector-app-7746c49485-tbnmd   1/1     Running   0          74s   10.131.2.73   user1-cluster-8kvh4-worker-eastus1-zj7dl   <none>           <none>
    ```

    Verify that the app was scheduled on a node that matches the output from the previous section's step four. 

1. And finally, if you'd like to view the app in your browser, get the route of the application. To do so, run the following command:

```bash
oc -n nodeselector-ex get route nodeselector-app -o jsonpath='{.spec.host}'
```

Then visit the URL presented in a new tab in your web browser (using HTTPS). For example, your output will look something similar to:

```bash
nodeselector-app-nodeselector-ex.apps.ce7l3kf6.eastus.aroapp.io
```

In that case, you'd visit `https://nodeselector-app-nodeselector-ex.apps.ce7l3kf6.eastus.aroapp.io` in your browser. 

Congratulations! You've successfully demonstrated the ability to label nodes and target those nodes using `nodeSelector`. 