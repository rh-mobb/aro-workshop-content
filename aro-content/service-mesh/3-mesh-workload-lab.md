## Enable Sidecars in all workloads

An Istio sidecar proxy adds a workload into the mesh.
Proxies connect with the control plane and provide [Service Mesh functionality](https://istio.io/latest/about/service-mesh/#what-is-istio).
Automatically providing metrics, logs and traces is a major feature of the sidecar.
In the previous steps we have added a sidecar only in the *travel-control* namespace's *control* workload.
We have added new powerful features but the application is still missing visibility from other workloads.
Switch to the Workload graph and select multiple namespaces to identify missing sidecars in the Travel Demo application
![Missing Sidecars](./images/04-01-missing-sidecars.png)

That *control* workload provides good visibility of its traffic, but telemetry is partially enabled, as *travel-portal* and *travel-agency* workloads don't have sidecar proxies.

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

![Updated Workloads](./images/04-01-updated-workloads.png)

Verify updated telemetry for *travel-portal* and *travel-agency* namespaces

![Updated Telemetry](./images/04-01-updated-telemetry.png)
