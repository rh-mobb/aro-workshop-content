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
    oc -n openshift-machine-api patch ${MACHINESET} -p '{"spec":{"template":{"spec":{"metadata":{"labels":{"tier":"frontend"}}}}}}'
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

```bash
MACHINES=$(oc -n openshift-machine-api get machines -o name \
  -l "machine.openshift.io/cluster-api-machineset=$MACHINESET" | xargs)
oc label -n openshift-machine-api "${MACHINES}" tier=frontend
NODE=$(echo $MACHINES | cut -d "/" -f 2)
oc label nodes "${NODE}" tier=frontend
```

@todo - stopping point mrmc

Click on one of the machines and you can see that the label is now there.

![checklabel](../assets/images/45-machine-label.png)

### Deploy an app to the labelled nodes

To test the functionality of deploying an app that uses `nodeSelector` to determine app placement, use the Deployment manifest provided below.

``` title="node-select-deployment.yaml"
--8<-- "node-select-deployment.yaml"
```

#### Deploy the app

Create a new project for the app:

```bash
oc new-project hello-openshift
```

Apply the manifest:

```bash
oc create -f \
  https://rh-mobb.github.io/aro-hackathon-content/assets/node-select-deployment.yaml
```

To view the app in a browser, get the route:

```bash
oc get route hello-openshift
```

Output:
```bash
NAME              HOST/PORT                                                        PATH   SERVICES          PORT   TERMINATION     WILDCARD
hello-openshift   hello-openshift-hello-openshift.apps.auo2ltzt.eastus.aroapp.io          hello-openshift   8080   edge/Redirect   None
```

To see that the app was scheduled on the correct node run the following commands:

```bash
 oc describe po -l app=hello-openshift | grep Node
```

Output:

```bash
Node:         workshop-prgbs-worker-eastus2-x7ltv/10.0.2.6
Node-Selectors:              tier=frontend
```

