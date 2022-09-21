## Understanding proxy injection
### Missing Sidcars
The Travel Demo has been deployed without installing sidecar proxy.
Without a sidecar the application will not connect to the control plane and won’t take advantage of Istio’s features.
In Kiali, **click** **overview** to see the all namespaces in the overview page:

![Overview](./images/overview.png)

1. Next **click** Graph.

We don't see traffic for namespaces without the sidecar injection enabled.

![Empty Graph](./images/empty-graph.png)

The applications, workloads and services page will confirm that that workloads and namespaces are missing sidecars:

![Missing Sidecar](./images/missing-sidecar.png)

## Enable Sidecars

In this tutorial, we will add namespaces and workloads into the ServiceMesh individually step by step.
This will help you to understand how Istio sidecar proxies work and how applications can use Istio's features.
We are going to start with the **control** workload deployed into the **travel-control** namespace:

**Enable** Auto Injection for **travel-control** namespace.

1. **Click** overview.

1. **Click** 3 dots on the right of **travel-control**.

1. **Click** **Enable Auto Injection**.

![Enable Auto Injection per Namespace](./images/travel-control-namespace.png)

**Enable** Auto Injection for **control** workload.

1. **Click** Workloard.

1. **Filter** for **travel-control** namespace.

1. **Click** control.

1. **Click** Action.

1. **Click** **Enable Auto Injection**.

![Enable Auto Injection per Workkload](./images/control-workload.png)

[Sidecar Injection](https://docs.openshift.com/container-platform/4.11/service_mesh/v2x/prepare-to-deploy-applications-ossm.html)

[Automatic Sidecar Injection](https://docs.openshift.com/container-platform/4.11/service_mesh/v2x/prepare-to-deploy-applications-ossm.html)
