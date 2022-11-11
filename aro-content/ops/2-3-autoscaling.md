## Introduction

The cluster autoscaler adjusts the size of an OpenShift Container Platform cluster to meet its current deployment needs. The cluster autoscaler increases the size of the cluster when there are pods that fail to schedule on any of the current worker nodes due to insufficient resources or when another node is necessary to meet deployment needs. The cluster autoscaler does not increase the cluster resources beyond the limits that you specify. To learn more visit the documentation for [cluster autoscaling](https://docs.openshift.com/container-platform/latest/machine_management/applying-autoscaling.html).

A ClusterAutoscaler must have at least 1 machine autoscaler in order for the cluster autoscaler to scale the machines. The cluster autoscaler uses the annotations on machine sets that the machine autoscaler sets to determine the resources that it can scale. If you define a cluster autoscaler without also defining machine autoscalers, the cluster autoscaler will never scale your cluster.

### Create a Machine Autoscaler

This can be accomplished via the Web Console or through the CLI with a YAML file for the custom resource definition. We'll use the latter.

!!! info
    This snippet will load a MachineSet into a variable and then write a MachineAutoscaler resource definition that we can apply later.

```bash
MACHINE_SET=$(oc -n openshift-machine-api get machinesets \
  -o name | cut -d / -f2 | head -1)
cat <<EOF > machine-autoscaler.yaml
apiVersion: "autoscaling.openshift.io/v1beta1"
kind: "MachineAutoscaler"
metadata:
  name: "${MACHINE_SET}"
  namespace: "openshift-machine-api"
spec:
  minReplicas: 1
  maxReplicas: 3
  scaleTargetRef:
    apiVersion: machine.openshift.io/v1beta1
    kind: MachineSet
    name: "${MACHINE_SET}"
EOF
```

Create the resource in the cluster. Assuming you kept the same filename:

```bash
oc create -f machine-autoscaler.yaml
```

You will see the following output:
``` {.text .no-copy}
machineautoscaler.autoscaling.openshift.io/ok0620-rq5tl-worker-westus21-mautoscaler created
```

You can also confirm this by checking the web console under "MachineAutoscalers" or by running:

```bash
oc  -n openshift-machine-api get machineautoscaler
```

You should see output similar to:

```{.text .no-copy}
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

```bash
oc create -f \
  https://rh-mobb.github.io/aro-hackathon-content/assets/cluster-autoscaler.yaml
```

Output:
```{.text .no-copy}
clusterautoscaler.autoscaling.openshift.io/default created
```

### Test the Cluster Autoscaler

Now we will test this out. Create a new project where we will define a job with a load that this cluster cannot handle. This should force the cluster to autoscale to handle the load.

Create a new project called "autoscale-ex":

```bash
oc new-project autoscale-ex
```

!!! info
    This is the job resource definition that will exhaust the cluster's resources and cause it to scale more worker nodes

``` title="job-work-queue.yaml"
--8<-- "job-work-queue.yaml"
```

Create the job

```bash
oc create -f \
  https://rh-mobb.github.io/aro-hackathon-content/assets/job-work-queue.yaml
```

After a few seconds, run the following to see what pods have been created.

```bash
oc get pods
```


```{.text .no-copy}
NAME                     READY   STATUS              RESTARTS   AGE
work-queue-28n9m-29qgj   1/1     Running             0          53s
work-queue-28n9m-2c9rm   0/1     Pending             0          53s
work-queue-28n9m-57vnc   0/1     Pending             0          53s
work-queue-28n9m-5gz7t   0/1     Pending             0          53s
work-queue-28n9m-5h4jv   0/1     Pending             0          53s
work-queue-28n9m-6jz7v   0/1     Pending             0          53s
work-queue-28n9m-6ptgh   0/1     Pending             0          53s
work-queue-28n9m-78rr9   1/1     Running             0          53s
work-queue-28n9m-898wn   0/1     ContainerCreating   0          53s
work-queue-28n9m-8wpbt   0/1     Pending             0          53s
work-queue-28n9m-9nm78   1/1     Running             0          53s
work-queue-28n9m-9ntxc   1/1     Running             0          53s
[...]
```

We see a lot of pods in a pending state.  This should trigger the cluster autoscaler to create more machines using the MachineAutoscaler we created. If we check on the MachineSets:

```bash
oc -n openshift-machine-api get machinesets
```

```{.text .no-copy}
NAME                           DESIRED   CURRENT   READY   AVAILABLE   AGE
ok0620-rq5tl-worker-westus21   5         5         1       1           7h17m
ok0620-rq5tl-worker-westus22   1         1         1       1           7h17m
ok0620-rq5tl-worker-westus23   1         1         1       1           7h17m
```

We see that the cluster autoscaler has already scaled the machine set up to 5 in our example. Though it is still waiting for those machines to be ready.

If we check on the machines we should see that 4 are in a "Provisioned" state (there was 1 already existing from before for a total of 5 in this machine set).

```bash
oc -n openshift-machine-api get machines \
  -l "machine.openshift.io/cluster-api-machine-role=worker"
```

```{.text .no-copy}
NAME                                 PHASE         TYPE              REGION    ZONE   AGE
ok0620-rq5tl-worker-westus21-7hqgz   Provisioned   Standard_D4s_v3   westus2   1      72s
ok0620-rq5tl-worker-westus21-7j22r   Provisioned   Standard_D4s_v3   westus2   1      73s
ok0620-rq5tl-worker-westus21-7n7nf   Provisioned   Standard_D4s_v3   westus2   1      72s
ok0620-rq5tl-worker-westus21-8m94b   Provisioned   Standard_D4s_v3   westus2   1      73s
ok0620-rq5tl-worker-westus21-qnlfl   Running       Standard_D4s_v3   westus2   1      13m
ok0620-rq5tl-worker-westus22-9dtk5   Running       Standard_D4s_v3   westus2   2      22m
ok0620-rq5tl-worker-westus23-hzggb   Running       Standard_D4s_v3   westus2   3      7h15m
```

After a few minutes we should see all 5 are provisioned.

```bash
oc -n openshift-machine-api get machinesets
```

```{.text .no-copy}
NAME                           DESIRED   CURRENT   READY   AVAILABLE   AGE
ok0620-rq5tl-worker-westus21   5         5         5       5           7h23m
ok0620-rq5tl-worker-westus22   1         1         1       1           7h23m
ok0620-rq5tl-worker-westus23   1         1         1       1           7h23m
```

You can watch the cluster autoscaler create more machines and to accomodate the extra workload and then delete them again after the job has completed

```bash
watch oc -n openshift-machine-api get machines \
  -l "machine.openshift.io/cluster-api-machine-role=worker"
```

```{.text .no-copy}
NAME                                 PHASE      TYPE              REGION    ZONE   AGE
ok0620-rq5tl-worker-westus21-7hqgz   Running    Standard_D4s_v3   westus2   1      10m
ok0620-rq5tl-worker-westus21-7j22r   Running    Standard_D4s_v3   westus2   1      10m
ok0620-rq5tl-worker-westus21-8m94b   Deleting   Standard_D4s_v3   westus2   1      10m
ok0620-rq5tl-worker-westus21-qnlfl   Running    Standard_D4s_v3   westus2   1      22m
ok0620-rq5tl-worker-westus22-9dtk5   Running    Standard_D4s_v3   westus2   2      32m
ok0620-rq5tl-worker-westus23-hzggb   Running    Standard_D4s_v3   westus2   3      7h24m
```
