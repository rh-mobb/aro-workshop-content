## Access the OpenShift Console and CLI

To access the OpenShift `oc` CLI and web console you will need to retrieve your cluster credentials. Use the cluster name and Resource Group name that were provided to you.

To retrieve the credentials run:

```bash
az aro list-credentials --name $USERID --resource-group $USERID
```

To retrieve the console URL run:

```bash
az aro show --name $USERID --resource-group $USERID -o tsv --query consoleProfile
```

Login to the console with the `kubeadmin` user through a browser.

### OpenShift CLI Login

Retrieve the API server's address.

```bash
apiServer=$(az aro show -g $USERID -n $USERID --query apiserverProfile.url -o tsv)
```

Login to the OpenShift cluster's API server using the following command. Replace <kubeadmin password> with the password you just retrieved.

```bash
oc login $apiServer -u kubeadmin -p <kubeadmin password>
```

