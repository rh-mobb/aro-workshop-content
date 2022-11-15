The [Azure Key Vault](https://azure.microsoft.com/en-us/products/key-vault/){:target="_blank"} Provider for Secrets Store CSI Driver allows for the integration of Azure Key Vault as a secrets store with an Azure Red Hat OpenShift cluster via a CSI volume. For Azure Arc-enabled ARO clusters, you can install the Azure Key Vault Secrets Provider extension to fetch secrets.

1. First, install the required Azure CLI extension. To do so, run the following command:

    ```bash
    az k8s-extension create --cluster-name "${AZ_ARO}" --resource-group "${AZ_RG}" \
      --cluster-type connectedClusters --name akvsecretsprovider \
      --extension-type Microsoft.AzureKeyVaultSecretsProvider
    ```

    This command takes about 5 minutes to complete. Once completed, your output will look something like this: 

    ```json
    [...]
    "installedVersion": null,
    "name": "akvsecretsprovider",
    "packageUri": null,
    "provisioningState": "Succeeded",
    "releaseTrain": "Stable",
    "resourceGroup": "user1-rg",
    [...]
    ```

1. Next, let's create a namespace (also known as a project in OpenShift). To do so, run the following command:

    ```bash
    oc new-project keyvault-ex
    ```

1. In order to use Azure Key Vault, we will need to create a vault and a secret in the cooresponding vault. To do so, run the following command:

    ```bash
    az keyvault create -n "${AZ_USER}-vault" \
      --resource-group "${AZ_RG}" -l eastus
    az keyvault secret set --vault-name "${AZ_USER}-vault" \
      -n DemoSecret --value MyExampleSecret
    ```

1. Next, let's get the necessary information for the Azure Key Vault CSI Driver to authenticate against Azure. To do so, run the following command:

    ```bash
    export AZURE_TENANT_ID="$(az account show -o tsv --query tenantId)"
    echo "Tenant ID: ${AZURE_TENANT_ID}"
    export AZURE_CLIENT_ID="$(oc get secret azure-credentials -n kube-system -o json | jq -r .data.azure_client_id | base64 --decode)"
    echo "Client ID: ${AZURE_CLIENT_ID}"
    export AZURE_CLIENT_SECRET="$(oc get secret azure-credentials -n kube-system -o json | jq -r .data.azure_client_secret | base64 --decode)"
    echo "Secret (Sensitive Information): ${AZURE_CLIENT_SECRET}"
    ```

1. Next, let's grant our cluster the ability to access the key vault. To do so, run the following command:

    ```bash
    OID="$(az ad sp show --id ${AZURE_CLIENT_ID} --query '{id:id}' -o tsv)"
    az keyvault set-policy --name "${AZ_USER}-vault" \
      --object-id "${OID}" \
      --secret-permissions get
    ```

1. Next, create a secret for the Azure Key Vault CSI Driver to use to authenticate against Azure. To do so, run the following command:

    ```bash
    oc -n keyvault-ex create secret generic secrets-store-creds \
      --from-literal clientid="${AZURE_CLIENT_ID}" \
      --from-literal clientsecret="${AZURE_CLIENT_SECRET}"
    oc -n keyvault-ex label secret secrets-store-creds secrets-store.csi.k8s.io/used=true
    ```

1. Next, create a SecretProviderClass for your Key Vault resource inside the cluster. 

    ```bash
    cat << EOF | oc apply -f -
    apiVersion: secrets-store.csi.x-k8s.io/v1
    kind: SecretProviderClass
    metadata:
      name: akvprovider-demo
      namespace: keyvault-ex 
    spec:
      provider: azure
      parameters:
        usePodIdentity: "false"
        keyvaultName: "${AZ_USER}-vault"
        objects:  |
          array:
            - |
              objectName: DemoSecret
              objectType: secret
              objectVersion: ""
        tenantId: "${AZURE_TENANT_ID}"
    EOF
    ```

1. Now, let's create a pod that can access the secret from Azure Key Vault. To do so, run the following command:

    ```yaml
    cat << EOF | oc apply -f -
    kind: Pod
    apiVersion: v1
    metadata:
      name: secret-store-pod
      namespace: keyvault-ex 
    spec:
      containers:
        - name: busybox
          image: k8s.gcr.io/e2e-test-images/busybox:1.29
          command:
            - "/bin/sleep"
            - "10000"
          volumeMounts:
          - name: secrets-store-inline
            mountPath: "/mnt/secrets-store"
            readOnly: true
      volumes:
        - name: secrets-store-inline
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "akvprovider-demo"
            nodePublishSecretRef:
              name: secrets-store-creds
    EOF
    ```

1. After the pod starts, the mounted secret from the Azure Key Vault specified in your deployment YAML is available. To demonstrate this, let's run the following two quick `oc exec` commands:

    ```bash
    ## show secrets held in secrets-store
    oc exec secret-store-pod -- ls /mnt/secrets-store/DemoSecret
    ## print a test secret 'DemoSecret' held in secrets-store
    oc exec secret-store-pod -- cat /mnt/secrets-store/DemoSecret
    ```

    The output of this command will return:

    ```
    /mnt/secrets-store/DemoSecret
    MyExampleSecret
    ```

Congratulations! You've successfully demonstrated using Azure Arc with your Azure Red Hat OpenShift cluster for observability and key vault. 