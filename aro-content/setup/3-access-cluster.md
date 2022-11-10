## Access the OpenShift Console and CLI

Ensure that your workshop environment has our helper variables configured

```bash
env | grep -E  'AZ_|OCP'
```

You should see a list of variables including `AZ_USER` and `OCP_CONSOLE`

To access the OpenShift `oc` CLI and web console you will need to retrieve your cluster credentials. The helper variables from above will make this simple!

To retrieve the credentials run:

```bash
az aro list-credentials --name "${AZ_ARO}" --resource-group "${AZ_RG}"
```

To retrieve the console URL run:

```bash
az aro show --name "${AZ_ARO}" --resource-group \
  "${AZ_RG}" -o tsv --query consoleProfile
```

Login to the console with the provided credentials through a browser.

### OpenShift CLI Login

To retrieve the API server's address.

```bash
az aro show -g "${AZ_RG}" -n "${AZ_ARO}" --query apiserverProfile.url -o tsv
```

Login to the OpenShift cluster's API server using the following command.

```bash
oc login "${OCP_API}" -u "${OCP_USER}" -p "${OCP_PASS}"
```

