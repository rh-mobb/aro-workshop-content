## Enable Sidecars in all workloads

An Istio sidecar proxy adds a workload into the mesh.
Proxies connect with the control plane and provide [Service Mesh functionality](https://docs.openshift.com/container-platform/4.11/service_mesh/v2x/ossm-about.html).
Automatically providing metrics, logs and traces is a major feature of the sidecar.
In the previous steps we enabled automatuc sidecar injection in **travel-control**.
The application is still missing visibility from other workloads.

1. **Click** graph type

1. **Select** Workload graph

1. Next **select** multiple namespaces to identify missing sidecars in the Travel Demo a\Application

![Missing Sidecars](./images/missing-sidecars.png)

The *control* workload provides good visibility of its traffic, but telemetry is partially enabled, as *travel-portal* and *travel-agency* workloads don't have sidecar proxies.

Enable proxy injection in *travel-portal* and *travel-agency* namespaces

In 2-mesh-workload-lab.md of this tutorial we didn't inject the sidecar proxies on purpose to show a scenario where only some workloads may have sidecars.

Typically, Istio users annotate namespaces before the deployment to allow Istio to automatically add the sidecar when the application is rolled out into the cluster. Perform
the following commands:

```
oc label namespace travel-agency istio-injection=enabled
oc label namespace travel-portal istio-injection=enabled

oc rollout restart deploy -n travel-portal
oc rollout restart deploy -n travel-agency
```

Verify that *travel-control*, *travel-portal* and *travel-agency* workloads have sidecars deployed:

![Updated Workloads](./images/updated-workloads.png)

**Verify** updated telemetry for *travel-portal* and *travel-agency* namespaces

![Updated Telemetry](./images/updated-telemetry.png)
