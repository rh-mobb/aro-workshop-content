## Deploying Workloads with OpenShift Service Mesh

1. First we will create a project for hosting the service mesh control plane.

```bash 
$ oc new-project bookinfo-mesh
```
### Install OpenShift Service Mesh
Under the project booking-mesh go to Operator Hub and install Red Hat OpenShift Service Mesh, Red Hat OpenShift Jaeger and Kiali Operator. 


#### Configure OpenShift Service Mesh

2. Create a service mesh member. Update the yaml and change namespace under controlPlaneRef to bookinfo-mesh.
```
apiVersion: maistra.io/v1
kind: ServiceMeshMember
metadata:
  namespace: bookinfo-mesh
  name: default
spec:
  controlPlaneRef:
    name: basic
    namespace: bookinfo-mesh
```    

3. Finally create a service member role adding name of the project that will access the service mesh..
```
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  namespace: bookinfo-mesh
  name: default
spec:
  members:
    - bookinfo
```    
### Deploy Demo Application

4. Create a project to host the book app.

```bash
$ oc new-project bookinfo
```
5. Deploy book app.
```bash
$ oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/platform/kube/bookinfo.yaml
```
6. Once the app is deployed we need to create a gateway and setup the URI matches.

```bash
$ oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/networking/bookinfo-gateway.yaml
```
7. Create service mesh rule set, since the ratings service has 3 API versions we need some rules to govern the traffic.

```bash
$ oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/networking/destination-rule-all.yaml
```
8. Access the application. Get the route to the application and add the /productpage to access via web browser.

```bash
$ export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
$ echo $GATEWAY_URL
```
### Update Service Mesh Ruleset

****Apply a new rule that only sends traffic to v2 (black) and v3 (red) ratings API.****

9. Apply New Ruleset
```bash
$ oc replace -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/networking/virtual-service-reviews-v2-v3.yaml
```
****When you access the book app and refresh you will switch between red and black ratings. Looking at Kiali versioned app graph we can see that traffic is only going to v2 and v3 as we would expect.
One of OpenShift Service Mesh major benefits are visualization and tracing. To generate an error we will scale down the ratings v1 deployment to 0.****

```bash
$ oc scale deployment/ratings-v1 -n bookinfo --replicas 0
```
****Now you will see that the ratings service is currently unavailable when you refresh the app in a browser.****

10. Check Kiali dashboard.

****You can access Kiali via route under networking in the bookinfo-mesh project. In Kiali we clearly see the issue is the reviews service as we would expect.****

11. Open Jaeger to trace the calls that are failing.

12. Dig into the requests by opening distributed tracing (Jaeger) from the Kiali dashboard to see the flow of all calls grouped and identify all request to the ratings service that are throwing an error.
