1. From the CLI, deploy the Bookinfo application in the `bookinfo` project by applying the bookinfo.yaml file:
```bash
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.2/samples/bookinfo/platform/kube/bookinfo.yaml
```
You should see output similar to the following:
```
service/details created
serviceaccount/bookinfo-details created
deployment.apps/details-v1 created
service/ratings created
serviceaccount/bookinfo-ratings created
deployment.apps/ratings-v1 created
service/reviews created
serviceaccount/bookinfo-reviews created
deployment.apps/reviews-v1 created
deployment.apps/reviews-v2 created
deployment.apps/reviews-v3 created
service/productpage created
serviceaccount/bookinfo-productpage created
deployment.apps/productpage-v1 created
```
1. Create the ingress gateway by applying the bookinfo-gateway.yaml file.

***An Istio Gateway describes a LoadBalancer operating at either side of the service mesh. Istio Gateways are of two types. Istio Ingress Gateway: Controlling the traffic coming inside the Mesh. Istio Egress Gateway: Controlling the traffic going outside the Mesh.***

```bash
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.2/samples/bookinfo/networking/bookinfo-gateway.yaml
```
You should see output similar to the following:
```
gateway.networking.istio.io/bookinfo-gateway created
virtualservice.networking.istio.io/bookinfo created
```
1. Set the value for the GATEWAY_URL parameter:
```
export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
```
#### Adding default destination rules

***DestinationRule defines policies that apply to traffic intended for a service after routing has occurred. These rules specify configuration for load balancing, connection pool size from the sidecar, and outlier detection settings to detect and evict unhealthy hosts from the load balancing pool. Before you can use the Bookinfo application, you must first add default destination rules.***

1. To add destination rules, run the following commands:
```bash
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.2/samples/bookinfo/networking/destination-rule-all.yaml
```
You should see output similar to the following:
```
destinationrule.networking.istio.io/productpage created
destinationrule.networking.istio.io/reviews created
destinationrule.networking.istio.io/ratings created
destinationrule.networking.istio.io/details created
```
### Verifying the Bookinfo installation
To confirm that the sample Bookinfo application was successfully deployed, perform the following steps.
1. Verify that all pods are ready with this command:
```bash
oc get pods -n bookinfo
```
All pods should have a status of Running. You should see output similar to the following:
```
NAME                              READY   STATUS    RESTARTS   AGE
details-v1-55b869668-jh7hb        2/2     Running   0          12m
productpage-v1-6fc77ff794-nsl8r   2/2     Running   0          12m
ratings-v1-7d7d8d8b56-55scn       2/2     Running   0          12m
reviews-v1-868597db96-bdxgq       2/2     Running   0          12m
reviews-v2-5b64f47978-cvssp       2/2     Running   0          12m
reviews-v3-6dfd49b55b-vcwpf       2/2     Running   0          12m
```
1. Run the following command to retrieve the URL for the product page:
```bash
echo "http://$GATEWAY_URL/productpage"
```
You should see output similar to the following:
```
http://istio-ingressgateway-istio-system.apps.qybf0l2n.eastus.aroapp.io/productpage
```

1. Copy and paste the output in a web browser to verify the Bookinfo product page is deployed.


### Traffic Management
### Metrics, Logs, and Traces

### Delete the Bookinfo project

1. Delete the Bookinfo project
```bash
oc delete project bookinfo
```
