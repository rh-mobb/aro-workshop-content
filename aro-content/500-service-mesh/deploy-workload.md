## Deploying Workloads

1. Create project.

    ```bash
    oc new-project bookinfo
    oc label namespace bookinfo istio-injection=enabled
    ```

1. Run the following command to create the Service Mesh Member Roll

    The `ServiceMeshMemberRoll` lists the projects that belong to the Service Mesh control plane. Only projects listed in the `ServiceMeshMemberRoll` are affected by the control plane. A project does not belong to a service mesh until you add it to the member roll for a particular control plane deployment.

    You must create a `ServiceMeshMemberRoll` resource named `default` in the same project as the `ServiceMeshControlPlane`, for example `istio-system`.

    ```bash
    cat << EOF | oc create -n istio-system -f -
    apiVersion: maistra.io/v1
    kind: ServiceMeshMemberRoll
    metadata:
      name: default
    spec:
      members:
      - bookinfo
    EOF
    ```

1. Run the following command to verify the ServiceMeshMemberRoll was created successfully.

    ```bash
    oc get smmr -n istio-system -o wide
    ```

    The installation has finished successfully when the STATUS column is Configured.

    ```{.text .no-copy}
    NAME      READY   STATUS       AGE   MEMBERS
    default   1/1     Configured   70s   ["bookinfo"]
    ```

1. From the CLI, deploy the Bookinfo application in the `bookinfo` project by applying the bookinfo.yaml file:

    ```bash
    oc apply -n bookinfo -f \
      https://ws.mobb.cloud/assets/bookinfo.yaml
    ```

    You should see output similar to the following:

    ```{.text .no-copy}
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

1. Create the ingress gateway by applying the bookinfo-gateway.yaml file:

    ```bash
    oc apply -n bookinfo -f \
      https://ws.mobb.cloud/assets/bookinfo-gateway.yaml
    ```

    You should see output similar to the following:

    ```bash
    gateway.networking.istio.io/bookinfo-gateway created
    virtualservice.networking.istio.io/bookinfo created
    ```

1. Set the value for the GATEWAY_URL parameter:

    ```bash
    export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
    echo "export GATEWAY_URL=${GATEWAY_URL}" >> ~/.workshoprc
    ```

### Adding default destination rules

1. To add destination rules, run one of the following commands:

```bash
oc apply -n bookinfo -f \
  https://ws.mobb.cloud/assets/destination-rule-all.yaml
```

You should see output similar to the following:

```{.text .no-copy}
destinationrule.networking.istio.io/productpage created
destinationrule.networking.istio.io/reviews created
destinationrule.networking.istio.io/ratings created
destinationrule.networking.istio.io/details created
```

### Verifying the Bookinfo installation

1. Verify that all pods are ready with this command:

    ```bash
    oc get pods -n bookinfo
    ```

    All pods should have a status of Running. You should see output similar to the following:

    ```{.text .no-copy}
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

1. Copy and paste the output in a web browser to verify the Bookinfo product page is deployed.

    You should see a book review of "The Comedy of Errors".
