## Introduction
 
The Managed Upgrade Operator has been created to manage the orchestration of automated in-place cluster upgrades.

Whilst the operator's job is to invoke a cluster upgrade, it does not perform any activities of the cluster upgrade process itself. This remains the responsibility of the OpenShift Container Platform. The operator's goal is to satisfy the operating conditions that a managed cluster must hold, both pre- and post-invocation of the cluster upgrade.

Examples of activities that are not core to an OpenShift upgrade process but could be handled by the operator include:

- Pre and post-upgrade health checks.
- Worker capacity scaling during the upgrade period.
- Alerting silence window management.

Configuring the Managed Upgrade Operator for ARO ensures that your cluster functions as you need it to during upgrades. The process of executing upgrades is shown here:

![MUO Upgrade Process](../assets/images/upgradecluster-flow.svg)

### Enable the Managed Upgrade Operator

Run this oc command to enable the Managed Upgrade Operator (MUO)

```
oc patch cluster.aro.openshift.io cluster --patch \
 '{"spec":{"operatorflags":{"rh.srep.muo.enabled": "true","rh.srep.muo.managed": "true","rh.srep.muo.deploy.pullspec":"arosvc.azurecr.io/managed-upgrade-operator@sha256:f57615aa690580a12c1e5031ad7ea674ce249c3d0f54e6dc4d070e42a9c9a274"}}}' \
 --type=merge
```

Wait a few moments to ensure the Management Upgrade Operator is ready, the status of the operator can be verified with:

```bash
oc -n openshift-managed-upgrade-operator \
  get deployment managed-upgrade-operator
```
```
NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
managed-upgrade-operator   1/1     1            1           2m2s
```

### Configure the Managed Upgrade Operator

Next, configure the Managed Upgrade Operator by using the following YAML:

``` title="muo-config-map.yaml"
--8<-- "muo-config-map.yaml"
```

You can apply the ConfigMap with this command:

```bash
oc apply -f https://rh-mobb.github.io/aro-hackathon-content/assets/muo-config-map.yaml
```

Restart the Managed Upgrade Operator

```
oc -n openshift-managed-upgrade-operator \
  scale deployment managed-upgrade-operator --replicas=0

oc -n openshift-managed-upgrade-operator \
  scale deployment managed-upgrade-operator --replicas=1
```

Look for available Upgrades

!!! info
    If the output is `nil` there are no available upgrades and you cannot continue.

```bash
oc get clusterversion version -o jsonpath='{.status.availableUpdates}'
```

### Schedule an Upgrade

!!! info
    Set the Channel and Version in the UpgradeConfig file to the desired values from the above list of available upgrades.

The configuration below will schedule an upgrade for the current date / time + 5 minutes, allow PDB-blocked nodes to drain for 60 minutes before a drain is forced, and sets a capacity reservation so that workloads are not interrupted during an upgrade.

``` title="muo-upgrade-config.yaml"
--8<-- "muo-upgrade-config.yaml"
```

To apply the UpgradeConfig you can run the following commands:

```bash
oc apply -f https://rh-mobb.github.io/aro-hackathon-content/assets/muo-upgrade-config.yaml
```

!!! warning
    If the cluster is on the latest version, the upgrade will not apply.


Check the status of the scheduled upgrade

```bash
oc -n openshift-managed-upgrade-operator get \
 upgradeconfigs.upgrade.managed.openshift.io \
 managed-upgrade-config -o jsonpath='{.status}' | jq
```

!!! info
    The output of this command should show upgrades in progress

```json
{
"history": [
  {
    "conditions": [
      {
        "lastProbeTime": "2022-04-12T14:42:02Z",
        "lastTransitionTime": "2022-04-12T14:16:44Z",
        "message": "ControlPlaneUpgraded still in progress",
        "reason": "ControlPlaneUpgraded not done",
        "startTime": "2022-04-12T14:16:44Z",
        "status": "False",
        "type": "ControlPlaneUpgraded"
      },
```

You can verify the upgrade has completed successfully via the following

```bash
oc get clusterversion version
```

```bash
NAME      VERSION   AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.9.27    True        False         161m    Cluster version is 4.9.27
```