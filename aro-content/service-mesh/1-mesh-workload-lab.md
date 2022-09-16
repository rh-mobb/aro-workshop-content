## RedHat Openshift Service Mesh

### Prerequisites

* an ARO cluster
* oc cli
* helm
* logged in to ARO cluster
* The Red Hat OpenShift Service Mesh Operator must be installed.
* An account with the cluster-admin role.

### Deploying the Service Mesh control plane from the web console
You can deploy a basic ServiceMeshControlPlane by using the web console. In this example, bookinfo-mesh is the name of the Service Mesh control plane project.

1. Create a project named istio-system.
   ```bash
   oc new-project bookinfo-mesh
   ```
2. Create a ServiceMeshControlPlane. The version of the Service Mesh control plane determines the features available regardless of the version of the Operator.
```
cat <<EOF | oc apply -f - 
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: bookinfo-mesh
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
oc get pods -n bookinfo-mesh -w
```
### Validating your SMCP installation with the CLI
You can validate the creation of the ServiceMeshControlPlane from the command line.
1. Run the following command to verify the Service Mesh control plane installation, where bookinfo-mesh is the namespace where you installed the Service Mesh control plane.
```bash
oc get smcp -n bookinfo-mesh
```
### Deploying Workloads
#### Creating the member roll from the CLI
You can add a project to the ServiceMeshMemberRoll from the command line.

### Prerequisites
* An installed, verified Red Hat OpenShift Service Mesh Operator.
* List of projects to add to the service mesh.
* Access to the OpenShift CLI (oc).
1. To add your projects as members, modify the following example YAML. You can add any number of projects, but a project can only belong to one ServiceMeshMemberRoll resource. In this example, bookinfo-mesh is the name of the Service Mesh control plane project.
```
cat <<EOF | oc apply -f - 
apiVersion: maistra.io/v1
kind: ServiceMeshMember
metadata:
  namespace: bookinfo-mesh
  name: default
spec:
  controlPlaneRef:
    name: basic
    namespace: bookinfo-mesh
   EOF
```
2. Run the following command to verify the ServiceMeshMemberRoll was created successfully.
```bash
oc get smmr -n bookinfo-mesh default
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
### Traffic Management
### Metrics, Logs, and Traces
