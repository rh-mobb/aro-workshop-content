## Understanding proxy injection and Gateways
### Missing Sidcars
The Travel Demo has been deployed in the previous step but without installing any Istio sidecar proxy.
In that case, the application won’t connect to the control plane and won’t take advantage of Istio’s features.
In Kiali, we will see the new namespaces in the overview page:

![Overview](./images/03-01-overview.png)

But we won't see any traffic in the graph page for any of these new namespaces:

![Empty Graph](./images/03-01-empty-graph.png)

If we examine the Applications, Workloads or Services page, it will confirm that there are missing sidecars:

![Missing Sidecar](./images/03-01-missing-sidecar.png)

## Enable Sidecars

In this tutorial, we will add namespaces and workloads into the ServiceMesh individually step by step.
This will help you to understand how Istio sidecar proxies work and how applications can use Istio's features.
We are going to start with the *control* workload deployed into the *travel-control* namespace:

Enable Auto Injection on the *travel-control* namespace

![Enable Auto Injection per Namespace](./images/03-02-travel-control-namespace.png)

Enable Auto Injection for *control* workload

![Enable Auto Injection per Workkload](./images/03-02-control-workload.png)

[Sidecar Injection](https://docs.openshift.com/container-platform/4.11/service_mesh/v2x/prepare-to-deploy-applications-ossm.html)

[Automatic Sidecar Injection](https://docs.openshift.com/container-platform/4.11/service_mesh/v2x/prepare-to-deploy-applications-ossm.html)
