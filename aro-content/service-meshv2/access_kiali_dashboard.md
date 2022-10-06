## Kiali Web Console
### Obtain the address for the Kiali web console.
***Under Mesh Project***

1. Log in to the OpenShift Container Platform web console as a user with cluster-admin rights. If you use Red Hat OpenShift Dedicated, you must have an account with the dedicated-admin role.

1. Navigate to project to Networking → Routes.

1. On the Routes page, select the Service Mesh control plane project, for example istio-system, from the Namespace menu.
![Project Network Route](../assets/images/click-network-under-project-view-kiali-route.PNG)

1. The Location column displays the linked address for each route.

1. Click the link in the Location column for Kiali.

1. Click Log In With OpenShift. The Kiali Overview screen presents tiles for each project namespace.
![Kiali Login](../assets/images/kiali-login-with-cluster-credentials.PNG)

1. Use Cluster Credentials to login.
```bash
 az aro list-credentials \
   --name $AZR_CLUSTER \
   --resource-group $AZR_RESOURCE_GROUP \
   -o tsv
```
1. Kiali Console.
![Kiali Console](../assets/images/Kiali-Console.PNG)

1. Change Time Settings to Last 6 hours and Every 15 minutes.
![Kiali Console Time Change](../assets/images/time-change.PNG)

1. In Kiali, click Graph.

1. Select bookinfo from the Namespace list, and App graph from the Graph Type list.

1. Click Display idle nodes from the Display menu.

1. Refresh URL in the browser to generate traffic for your graph.
