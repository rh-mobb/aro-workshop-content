## Deplying Workloads
1. Create project.
```bash
oc new-project bookinfo
```
2. Run the following command 
```bash
oc create -n istio-system -f https://raw.githubusercontent.com/rh-mobb/aro-hackathon-content/main/aro-content/assets/servicemeshmemberroll-default.yaml
```
3. Run the following command to verify the ServiceMeshMemberRoll was created successfully.
```bash
oc get smmr -n istio-system -o wide
```
The installation has finished successfully when the STATUS column is Configured.
```bash
NAME      READY   STATUS       AGE   MEMBERS
default   1/1     Configured   70s   ["bookinfo"]
```
4. From the CLI, deploy the Bookinfo application in the `bookinfo` project by applying the bookinfo.yaml file:
```bash
oc apply -n bookinfo -f https://raw.githubusercontent.com/rh-mobb/aro-hackathon-content/main/aro-content/assets/bookinfo.yaml
```
You should see output similar to the following:
```bash
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
5. Create the ingress gateway by applying the bookinfo-gateway.yaml file:
```bash
oc apply -n bookinfo -f https://raw.githubusercontent.com/rh-mobb/aro-hackathon-content/main/aro-content/assets/bookinfo-gateway.yaml
```
You should see output similar to the following:
```bash
gateway.networking.istio.io/bookinfo-gateway created
virtualservice.networking.istio.io/bookinfo created
```
6. Set the value for the GATEWAY_URL parameter:
```bash
export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
```
