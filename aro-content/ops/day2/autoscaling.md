## Introduction

The cluster autoscaler adjusts the size of an OpenShift Container Platform cluster to meet its current deployment needs. The cluster autoscaler increases the size of the cluster when there are pods that fail to schedule on any of the current worker nodes due to insufficient resources or when another node is necessary to meet deployment needs. The cluster autoscaler does not increase the cluster resources beyond the limits that you specify. To learn more visit the documentation for [cluster autoscaling](https://docs.openshift.com/container-platform/latest/machine_management/applying-autoscaling.html).

A ClusterAutoscaler must have at least 1 machine autoscaler in order for the cluster autoscaler to scale the machines. The cluster autoscaler uses the annotations on machine sets that the machine autoscaler sets to determine the resources that it can scale. If you define a cluster autoscaler without also defining machine autoscalers, the cluster autoscaler will never scale your cluster.

### Create a Machine Autoscaler

This can be accomplished via the Web Console or through the CLI with a YAML file for the custom resource definition. We'll use the latter.

Download the sample [MachineAutoscaler resource definition](https://rh-mobb.github.io/aro-hackathon-content/assets/machine-autoscaler.yaml) and open it in your favorite editor.

For `metadata.name` give this machine autoscaler a name. Technically, this can be anything you want. But to make it easier to identify which machine set this machine autoscaler affects, specify or include the name of the machine set to scale. The machine set name takes the following form: clusterid-machineset-region-az.

For `spec.ScaleTargetRef.name` enter the name of the exact MachineSet you want this to apply to. Below is an example of a completed file.

``` title="machine-autoscaler.yaml"
--8<-- "machine-autoscaler.yaml"
```

Save your file.

Then create the resource in the cluster. Assuming you kept the same filename:

```bash
oc create -f machine-autoscaler.yaml
```

You will see the following output:
```
machineautoscaler.autoscaling.openshift.io/ok0620-rq5tl-worker-westus21-mautoscaler created
```

You can also confirm this by checking the web console under "MachineAutoscalers" or by running:

```bash
oc get machineautoscaler -n openshift-machine-api
```

You should see output similar to:
```
NAME                           REF KIND     REF NAME                      MIN   MAX   AGE
ok0620-rq5tl-worker-westus21   MachineSet   ok0620-rq5tl-worker-westus2   1     7     40s
```

### Create the Cluster Autoscaler

This is the sample [ClusterAutoscaler resource definition](https://rh-mobb.github.io/aro-hackathon-content/assets/cluster-autoscaler.yaml) for this workshop:

``` title="cluster-autoscaler.yaml"
--8<-- "cluster-autoscaler.yaml"
```

See the [documentation](https://docs.openshift.com/container-platform/latest/machine_management/applying-autoscaling.html#cluster-autoscaler-cr_applying-autoscaling) for a detailed explanation of each parameter. You shouldn't need to edit this file.

Create the resource in the cluster:

<<<<<<< HEAD:aro-content/ops/day2/autoscaling.md
    ```bash
    oc create -f https://ws.mobb.cloud/assets/job-maxscale.yaml
    ```
=======
```bash
oc create -f https://rh-mobb.github.io/aro-hackathon-content/assets/cluster-autoscaler.yaml
```
>>>>>>> a78436f (initial v2):aro-content/ops/2-3-autoscaling.md

Output:
```bash
clusterautoscaler.autoscaling.openshift.io/default created
```

### Test the Cluster Autoscaler
We will be testing out the autoscaler in the next section when we scale up the frontend.