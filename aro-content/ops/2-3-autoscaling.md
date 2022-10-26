## Introduction

The cluster autoscaler adjusts the size of an OpenShift Container Platform cluster to meet its current deployment needs. The cluster autoscaler increases the size of the cluster when there are pods that fail to schedule on any of the current worker nodes due to insufficient resources or when another node is necessary to meet deployment needs. The cluster autoscaler does not increase the cluster resources beyond the limits that you specify. To learn more visit the documentation for [cluster autoscaling](https://docs.openshift.com/container-platform/latest/machine_management/applying-autoscaling.html).

A ClusterAutoscaler must have at least 1 machine autoscaler in order for the cluster autoscaler to scale the machines. The cluster autoscaler uses the annotations on machine sets that the machine autoscaler sets to determine the resources that it can scale. If you define a cluster autoscaler without also defining machine autoscalers, the cluster autoscaler will never scale your cluster.

### Create a Machine Autoscaler

This can be accomplished via the Web Console or through the CLI with a YAML file for the custom resource definition. We'll use the latter.

Download the sample [MachineAutoscaler resource definition](https://rh-mobb.github.io/aro-hackathon-content/assets/machine-autoscaler.yaml) and open it in your favorite editor.

For `metadata.name` give this machine autoscaler a name. Technically, this can be anything you want. But to make it easier to identify which machine set this machine autoscaler affects, specify or include the name of the machine set to scale. The machine set name takes the following form: <clusterid>-<machineset>-<region-az>.

For `spec.ScaleTargetRef.name` enter the name of the exact MachineSet you want this to apply to. Below is an example of a completed file.

``` title="machine-autoscaler.yaml"
--8<-- "machine-autoscaler.yaml"
```

Save your file.

Then create the resource in the cluster. Assuming you kept the same filename:

```
$ oc create -f machine-autoscaler.yaml
machineautoscaler.autoscaling.openshift.io/ok0620-rq5tl-worker-westus21-mautoscaler created
```

You can also confirm this by checking the web console under "MachineAutoscalers" or by running:

```
$ oc get machineautoscaler -n openshift-machine-api
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

```
$ oc create -f https://rh-mobb.github.io/aro-hackathon-content/assets/cluster-autoscaler.yaml
clusterautoscaler.autoscaling.openshift.io/default created
```

### Test the Cluster Autoscaler

Now we will test this out. Create a new project where we will define a job with a load that this cluster cannot handle. This should force the cluster to autoscale to handle the load.

Create a new project called "autoscale-ex":

```bash
oc new-project autoscale-ex
```

Create the job

```bash
oc create -f https://raw.githubusercontent.com/openshift/training/master/assets/job-work-queue.yaml
```

After a few seconds, run the following to see what pods have been created.

```bash
oc get pods
```


```
$ oc get pods
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

```
$ oc get machinesets -n openshift-machine-api
NAME                           DESIRED   CURRENT   READY   AVAILABLE   AGE
ok0620-rq5tl-worker-westus21   5         5         1       1           7h17m
ok0620-rq5tl-worker-westus22   1         1         1       1           7h17m
ok0620-rq5tl-worker-westus23   1         1         1       1           7h17m
```

We see that the cluster autoscaler has already scaled the machine set up to 5 in our example. Though it is still waiting for those machines to be ready.

If we check on the machines we should see that 4 are in a "Provisioned" state (there was 1 already existing from before for a total of 5 in this machine set).

```
$ oc get machines -n openshift-machine-api
NAME                                 PHASE         TYPE              REGION    ZONE   AGE
ok0620-rq5tl-master-0                Running       Standard_D8s_v3   westus2   1      7h18m
ok0620-rq5tl-master-1                Running       Standard_D8s_v3   westus2   2      7h18m
ok0620-rq5tl-master-2                Running       Standard_D8s_v3   westus2   3      7h18m
ok0620-rq5tl-worker-westus21-7hqgz   Provisioned   Standard_D4s_v3   westus2   1      72s
ok0620-rq5tl-worker-westus21-7j22r   Provisioned   Standard_D4s_v3   westus2   1      73s
ok0620-rq5tl-worker-westus21-7n7nf   Provisioned   Standard_D4s_v3   westus2   1      72s
ok0620-rq5tl-worker-westus21-8m94b   Provisioned   Standard_D4s_v3   westus2   1      73s
ok0620-rq5tl-worker-westus21-qnlfl   Running       Standard_D4s_v3   westus2   1      13m
ok0620-rq5tl-worker-westus22-9dtk5   Running       Standard_D4s_v3   westus2   2      22m
ok0620-rq5tl-worker-westus23-hzggb   Running       Standard_D4s_v3   westus2   3      7h15m
```

After a few minutes we should see all 5 are provisioned.

```
$ oc get machinesets -n openshift-machine-api
NAME                           DESIRED   CURRENT   READY   AVAILABLE   AGE
ok0620-rq5tl-worker-westus21   5         5         5       5           7h23m
ok0620-rq5tl-worker-westus22   1         1         1       1           7h23m
ok0620-rq5tl-worker-westus23   1         1         1       1           7h23m
```

If we now wait a few more minutes for the pods to complete, we should see the cluster autoscaler begin scale down the machine set and thus delete machines.

```
$ oc get machinesets -n openshift-machine-api
NAME                           DESIRED   CURRENT   READY   AVAILABLE   AGE
ok0620-rq5tl-worker-westus21   4         4         4       4           7h27m
ok0620-rq5tl-worker-westus22   1         1         1       1           7h27m
ok0620-rq5tl-worker-westus23   1         1         1       1           7h27m


$ oc get machines -n openshift-machine-api
NAME                                 PHASE      TYPE              REGION    ZONE   AGE
ok0620-rq5tl-master-0                Running    Standard_D8s_v3   westus2   1      7h28m
ok0620-rq5tl-master-1                Running    Standard_D8s_v3   westus2   2      7h28m
ok0620-rq5tl-master-2                Running    Standard_D8s_v3   westus2   3      7h28m
ok0620-rq5tl-worker-westus21-7hqgz   Running    Standard_D4s_v3   westus2   1      10m
ok0620-rq5tl-worker-westus21-7j22r   Running    Standard_D4s_v3   westus2   1      10m
ok0620-rq5tl-worker-westus21-8m94b   Deleting   Standard_D4s_v3   westus2   1      10m
ok0620-rq5tl-worker-westus21-qnlfl   Running    Standard_D4s_v3   westus2   1      22m
ok0620-rq5tl-worker-westus22-9dtk5   Running    Standard_D4s_v3   westus2   2      32m
ok0620-rq5tl-worker-westus23-hzggb   Running    Standard_D4s_v3   westus2   3      7h24m
```