## RedHat Openshift Service Mesh

### Prerequisites

* an ARO cluster
* oc cli
* helm
* logged in to ARO cluster
* The Red Hat OpenShift Service Mesh Operator must be installed.
* An account with the cluster-admin role.
* Control Plane istio-system

### Deploying the Service Mesh control plane from the web console
You can deploy a basic ServiceMeshControlPlane by using the web console. In this example, istio-system is the name of the Service Mesh control plane project.

1. Create a project named istio-system.
```bash
   oc new-project istio-system
```
2. Create a ServiceMeshControlPlane. The version of the Service Mesh control plane determines the features available regardless of the version of the Operator.
```
cat <<EOF | oc apply -f - 
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  version: v2.2
  tracing:
    type: Jaeger
    sampling: 10000
  addons:
    jaeger:
      name: jaeger
      install:
        storage:
          type: Memory
    kiali:
      enabled: true
      name: kiali
    grafana:
      enabled: true
   EOF
```
3. To watch the progress of the pod deployment, run the following command:
```bash
oc get pods -n istio-system -w
```
### Validating your SMCP installation with the CLI
You can validate the creation of the ServiceMeshControlPlane from the command line.
1. Run the following command to verify the Service Mesh control plane installation, where istio-system is the namespace where you installed the Service Mesh control plane.
```bash
oc get smcp -n istio-system
```
### Deploying Workloads
#### Creating the member roll from the CLI
You can add a project to the ServiceMeshMemberRoll from the command line.

### Prerequisites
* An installed, verified Red Hat OpenShift Service Mesh Operator.
* List of projects to add to the service mesh.
* Access to the OpenShift CLI (oc).
1. CLI to create the bookinfo project.
```
oc new-project bookinfo
```
2. To add your projects as members, modify the following example YAML. You can add any number of projects, but a project can only belong to one ServiceMeshMemberRoll resource. In this example, istio-system is the name of the Service Mesh control plane project.
```
cat <<EOF | oc apply -f - 
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
    # a list of projects joined into the service mesh
    - bookinfo
   EOF
```
2. Run the following command to verify the ServiceMeshMemberRoll was created successfully.
```bash
oc get smmr -n istio-system default
```
3. From the CLI, deploy the Bookinfo application in the `bookinfo` project by applying the bookinfo.yaml file:
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
4. Create the ingress gateway by applying the bookinfo-gateway.yaml file:
```bash
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.2/samples/bookinfo/networking/bookinfo-gateway.yaml
```
You should see output similar to the following:
```
gateway.networking.istio.io/bookinfo-gateway created
virtualservice.networking.istio.io/bookinfo created
```
5. Set the value for the GATEWAY_URL parameter:
```
export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
```
#### Adding default destination rules
Before you can use the Bookinfo application, you must first add default destination rules.
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
2. Run the following command to retrieve the URL for the product page:
```bash
echo "http://$GATEWAY_URL/productpage"
```
3. Copy and paste the output in a web browser to verify the Bookinfo product page is deployed.


### Traffic Management
### Metrics, Logs, and Traces

### Delete the Bookinfo project

1. Delete the Bookinfo project
```bash
oc delete project bookinfo
```

### Remove the Bookinfo project from the Service Mesh member roll

You can run this command using the CLI to remove the bookinfo project from the ServiceMeshMemberRoll. In this example, istio-system is the name of the Service Mesh control plane project.
```bash
oc -n istio-system patch --type='json' smmr default -p '[{"op": "remove", "path": "/spec/members", "value":["'"bookinfo"'"]}]'
```
