## Introduction

Labels are a useful way to select which nodes / machine sets that an application will run on. If you have a memory intensive application, you may choose to use a memory heavy node type to place that application on. By using labels on the machinesets and selectors on your pod / deployment specification, you ensure thats where the application lands.

While you can directly add a label to a node it is not recommended as nodes can be restarted or recreated and the label would disappear. Therefore we need to label the MachineSet itself, however only new Machines created by the MachineSet will get the label, this means you will need to either scale the MachineSet down to zero then back up, or you can label the existing nodes.

### Use the Web Console to set a label for the MachineSet

Select "MachineSets" from the left menu.  You will see the list of machinesets.

![webconsollemachineset](../assets/images/43-machinesets.png)

Select a machine set that was not used in the previous autoscaling activity such as `workshop-prgbs-worker-eastus2`

Click on the second tab **YAML**

Click into the text editor and find `spec.template.spec.metadata.labels` add a key:value pair for the label you want.  In our example we can add a label `tier: frontend`. Click **Save**.

![webconsollemachineset](../assets/images/44-edit-machinesets.png)

The already existing machines won't get this label but any new machines will. Rather than scale the MachineSet down to zero and back up which may disrupt your workloads you can write a quick script to label all machines that belong to the machineset.

First set a variable containing the machineset you just modified:

```bash
MACHINESET=<machineset name>
```

Next label each machine in that machineset:

!!! info
    MachineSets do not automatically relabel their existing child resources, this means we need to relabel them ourselves to avoid having to restart them.

```bash
MACHINES=$(oc -n openshift-machine-api get machines -o name \
  -l "machine.openshift.io/cluster-api-machineset=$MACHINESET" | xargs)
oc label -n openshift-machine-api "${MACHINES}" tier=frontend
NODE=$(echo $MACHINES | cut -d "/" -f 2)
oc label nodes "${NODE}" tier=frontend
```

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

