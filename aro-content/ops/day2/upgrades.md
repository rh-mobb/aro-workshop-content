## Introduction
<<<<<<< HEAD:aro-content/ops/day2/upgrades.md

Azure Red Hat OpenShift (ARO) provides fully-managed cluster updates. These updates can be triggered from inside the OpenShift Console, or scheduled in advance by utilizing the Managed Upgrade Operator. All updates are monitored and managed by the Red Hat and Microsoft ARO SRE team.

For more information on how OpenShift's Upgrade Service works, please see the [Red Hat documentation](https://docs.openshift.com/container-platform/4.10/updating/index.html){:target="_blank"}.

## Upgrade using the OpenShift Web Console

1. Return to your tab with the OpenShift Web Console. If you need to reauthenticate, follow the steps in the [Access Your Cluster](../setup/3-access-cluster/) section.

1. Using the menu on the left Select *Administration* -> *Cluster Settings*.

    ![Web Console - Cluster Settings](/assets/images/web-console-cluster-settings.png){ align=center }

1. Click on the *Not Configured* link under the *Upgrade Channel* heading.

    ![Web Console - Upgrade Channel Not Configured](/assets/images/web-console-upgrade-channel-not-configured.png){ align=center }

    !!! warning "Upgrade channel is not configured by default"

        By default, the [upgrade channel](https://docs.openshift.com/container-platform/4.10/updating/understanding-upgrade-channels-release.html){:target="_blank"} (which is used to recommend the appropriate release versions for cluster updates), is not set in ARO.

1. In the *Channel* field, enter `stable-4.10` to set the upgrade channel to the stable releases of OpenShift 4.10 and click *Save*.

    ![Web Console - Input Channel](/assets/images/web-console-input-channel.png){ align=center }

1. In a moment, you'll begin to see what upgrades are available for your cluster. From here, you could click the *Select a version* button and upgrade the cluster, or you could follow the instructions below to use the Managed Upgrade Operator.

    ![Web Console - Available Upgrades](../../Images/aro-console-upgrade.png)

## Upgrade using the Managed Upgrade Operator

=======
 
>>>>>>> a78436f (initial v2):aro-content/ops/2-1-upgrades.md
The Managed Upgrade Operator has been created to manage the orchestration of automated in-place cluster upgrades.

Whilst the operator's job is to invoke a cluster upgrade, it does not perform any activities of the cluster upgrade process itself. This remains the responsibility of the OpenShift Container Platform. The operator's goal is to satisfy the operating conditions that a managed cluster must hold, both pre- and post-invocation of the cluster upgrade.

Examples of activities that are not core to an OpenShift upgrade process but could be handled by the operator include:

- Pre and post-upgrade health checks.
- Worker capacity scaling during the upgrade period.
- Alerting silence window management.

Configuring the Managed Upgrade Operator for ARO ensures that your cluster functions as you need it to during upgrades. The process of executing upgrades is shown here:

<<<<<<< HEAD:aro-content/ops/day2/upgrades.md
![MUO Upgrade Process Flow Chart](/assets/images/upgradecluster-flow.svg)

1. First, let's check for available upgrades on your current upgrade channel. To do so, run the following command:
=======
![MUO Upgrade Process](../assets/images/upgradecluster-flow.svg)

### Enable the Managed Upgrade Operator
>>>>>>> a78436f (initial v2):aro-content/ops/2-1-upgrades.md

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

<<<<<<< HEAD:aro-content/ops/day2/upgrades.md
1. Once created, we can see that the update is pending by running the following command:
=======
Next, configure the Managed Upgrade Operator by using the following YAML:
>>>>>>> a78436f (initial v2):aro-content/ops/2-1-upgrades.md

``` title="muo-config-map.yaml"
--8<-- "muo-config-map.yaml"
```

You can apply the ConfigMap with this command:

```bash
oc apply -f https://rh-mobb.github.io/aro-hackathon-content/assets/muo-config-map.yaml
```

<<<<<<< HEAD:aro-content/ops/day2/upgrades.md
    Congratulations! You've successfully scheduled an upgrade of your cluster for tomorrow at this time. While the workshop environment will be deleted before then, you now have the experience to schedule upgrades in the future.
=======
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
c -n openshift-managed-upgrade-operator get \
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
>>>>>>> a78436f (initial v2):aro-content/ops/2-1-upgrades.md
