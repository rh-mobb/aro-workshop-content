## Kiali Web Console
### Obtain the address for the Kiali web console.

1. **Browse** to the OpenShift Container Platform web console.

1. **Navigate** to project to Networking → Routes.

1. **Click** on the Routes tab, **select** the Service Mesh control plane project, for example `istio-system`, from the Namespace menu.
![Project Network Route](../assets/images/click-network-under-project-view-kiali-route.PNG)

1. The Location column displays the linked address for each route.

1. **Click** the link in the Location column for Kiali.

1. **Click Login With OpenShift**. The Kiali Overview screen presents tiles for each project namespace.

![Kiali Login](../assets/images/kiali-login-with-cluster-credentials.PNG)

![URL](../assets/images/product-page.PNG)

1. Kiali Console.
![Kiali Console](../assets/images/verify-overiview-bookinfoapp.PNG)

1. In Kiali, **click Graph.**

1. **Select** bookinfo from the Namespace list, and App graph from the Graph Type list.
![Kiali Console](../assets/images/select-bookinfo-from-kiali-dropdown-graph-tab.PNG)

1. **Click** Display idle nodes.
![Kiali Console](../assets/images/kiali-click-display-idlenodes-graph-tab.PNG)

1. **View** Graph and change display settings to add or remove information from the graph.
![Kiali Console](../assets/images/graph-example.PNG)

1. **Click Workload tab**

1. **Select Details Workload**
![Kiali Console](../assets/images/example-details-workload.PNG)

