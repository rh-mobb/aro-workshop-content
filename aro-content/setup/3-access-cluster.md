## Access the OpenShift Console and CLI

First, let's ensure that your workshop environment has our helper variables configured. To do so, let's run the following command:

```bash
env | grep -E 'AZ_|OCP'
```

You should see a list of variables including `AZ_USER` and `OCP_CONSOLE`.

!!! info "Helper Variables"

    We use helper variables extensively throughout this workshop, but we also include the commands we used to populate these helper variables to ensure you can craft these commands later. 

To access the OpenShift `oc` CLI and web console you will need to retrieve your cluster credentials. The helper variables from above will make this simple!

To retrieve the credentials, run the following command:

```bash
az aro list-credentials --name "${AZ_ARO}" --resource-group "${AZ_RG}"
```

Then, to retrieve the console URL, run the following command:

```bash
az aro show --name "${AZ_ARO}" --resource-group \
  "${AZ_RG}" -o tsv --query consoleProfile
```

Finally, open the link to the console provided in a separate tab, and login with the provided credentials. 

### OpenShift CLI Login

Now that you're logged into the cluster's console, return to your Azure Cloud Shell. To login to the cluster using the OpenShift CLI tools (`oc`), first we need to retrieve the API server endpoint. To do so, run the following command:

```bash
az aro show -g "${AZ_RG}" -n "${AZ_ARO}" --query apiserverProfile.url -o tsv
```

Now that we've captured the API server endpoint, we can login to the cluster by running the following command:

```bash
oc login "${OCP_API}" -u "${OCP_USER}" -p "${OCP_PASS}"
```