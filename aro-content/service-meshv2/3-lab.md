## Enabling automatic sidecar injection
1. To find your deployments use the oc get command.
```bash
oc get deployment -n bookinfo
```
2. For example, to view the deployment file for the 'ratings-v1' microservice in the bookinfo namespace, use the following command to see the resource in YAML format.
```bash
oc get deployment -n bookinfo ratings-v1 -o yaml
```
3. Open the application’s deployment configuration YAML file in an editor.
4. Add spec.template.metadata.annotations.sidecar.istio/inject to your Deployment YAML and set sidecar.istio.io/inject to true as shown in the following example.

***Example snippet from bookinfo deployment-ratings-v1.yaml***
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ratings-v1
  namespace: bookinfo
  labels:
    app: ratings
    version: v1
spec:
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: 'true'
 ```
 5. Save the Deployment configuration file.
 6. Add the file back to the project that contains your app.
 ```bash
 oc apply -n bookinfo -f https://raw.githubusercontent.com/rh-mobb/aro-hackathon-content/main/aro-content/assets/deployment-ratings-v1.yaml
 ```
 7. To verify that the resource uploaded successfully, run the following command.
 ```bash
 oc get deployment -n bookinfo ratings-v1 -o yaml
 ```
