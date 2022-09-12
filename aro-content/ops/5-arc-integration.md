# Integrating Azure ARC with ARO
In this section of the workshop, we will integrate ARO cluster with Azure Arc-enabled Kubernetes. When you connect a Kubernetes/OpenShift cluster with Azure Arc, it will:
* Be represented in Azure Resource Manager with a unique ID
* Be place in an Azure subscription and resource group 
* Receive tags just like any otherAzure resource

Azure Arc-enabled Kubernetes supports the following scenarios for connected clusters:
* Connect Kubernetes running outside of Azure for inventory, grouping, and tagging.
* Deploy applications and apply configuration using GitOps-based configuration management.
* View and monitor your clusters using Azure Monitor for containers.
* Enforce threat protection using Microsoft Defender for Kubernetes.
* Apply policy definitions using Azure Policy for Kubernetes.
* Use Azure Active Directory for authentication and authorization checks on your cluster




## Prerequisites
* a public ARO cluster
* azure cli 
* oc cli
* An identity (user or service principal) which can be used to log in to Azure CLI and connect your cluster to Azure Arc.
* Install the connectedk8s Azure Cli extension of version >= 1.2.0
  * ```bash
    az extension add --name "connectedk8s"
    az extension add --name "k8s-configuration"
    az extension add --name "k8s-extension"
    ```
* Register providers for Azure Arc-enabled Kubernetes. Registration may take up to 10 minutes.
  * ```bash 
    az provider register --namespace Microsoft.Kubernetes
    az provider register --namespace Microsoft.KubernetesConfiguration
    az provider register --namespace Microsoft.ExtendedLocation
    ```

## Connect an existing ARO cluster
Make sure you are logged into your ARO cluster
```bash
kubeadmin_password=$(az aro list-credentials --name <<cluster name>> --resource-group <<resource group name>> --query kubeadminPassword --output tsv)   
apiServer=$(az aro show -g <<resource group name>> -n <<cluster name>> --query apiserverProfile.url -o tsv)

oc login $apiServer -u kubeadmin -p $kubeadmin_password
```

OpenShift Prep before connecting 
```bash
NS="flux-system"
oc adm policy add-scc-to-user privileged system:serviceaccount:azure-arc:azure-arc-kube-aad-proxy-sa
oc adm policy add-scc-to-user nonroot system:serviceaccount:$NS:kustomize-controller
oc adm policy add-scc-to-user nonroot system:serviceaccount:$NS:helm-controller
oc adm policy add-scc-to-user nonroot system:serviceaccount:$NS:source-controller
oc adm policy add-scc-to-user nonroot system:serviceaccount:$NS:notification-controller
oc adm policy add-scc-to-user nonroot system:serviceaccount:$NS:image-automation-controller
oc adm policy add-scc-to-user nonroot system:serviceaccount:$NS:image-reflector-controller
```

Run the following command:
```bash
az connectedk8s connect --name <<cluster name>> --resource-group <<resource group name>> --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"
```

This commands take about 5 mins to complete. Once the command complete, you should see your cluster under Kubernetes - Azure Arc service in Azure Portal

## Enable observability 
In order to see ARO resource inside Azure Arc, you need to create a service account and provide it to Azure Arc. 

```bash
oc create serviceaccount azure-arc-observability
oc create clusterrolebinding azure-arc-observability-rb --clusterrole cluster-admin --serviceaccount azure-arc:azure-arc-observability
````

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: azure-arc-observability-secret
  namespace: azure-arc
  annotations:
    kubernetes.io/service-account.name: azure-arc-observability
type: kubernetes.io/service-account-token
EOF
```

```bash
TOKEN=$(oc get secret azure-arc-observability-secret -o jsonpath='{$.data.token}' | base64 -d | sed 's/$/\\\n/g')
echo $TOKEN
```

Copy the token, goto Azure portal and select your cluster under "Kubernetes - Azure Arc"
Select Namespaces from the left side menu and paste the token in "Service account bearer token" input field. 

![Image](aro-arc-integration-image1.png)

Now you can see all of your ARO rearouses inside ARC UI.

## Deploy Applications using GitOps with Flux v2

```bash
az k8s-configuration flux create -g flux-demo-rg \
-c flux-demo-arc \
-n cluster-config \
--namespace cluster-config \
-t connectedClusters \
--scope cluster \
-u https://github.com/Azure/gitops-flux2-kustomize-helm-mt \
--branch main  \
--kustomization name=infra path=./infrastructure prune=true \
--kustomization name=apps path=./apps/staging prune=true dependsOn=\["infra"\]
```

## Access Secrets from Azure Key Vault
The Azure Key Vault Provider for Secrets Store CSI Driver allows for the integration of Azure Key Vault as a secrets store with a Kubernetes cluster via a CSI volume. For Azure Arc-enabled Kubernetes clusters, you can install the Azure Key Vault Secrets Provider extension to fetch secrets.

### Install extension
```bash
az k8s-extension create --cluster-name <<cluster name>> --resource-group <<resource group>> --cluster-type connectedClusters --extension-type Microsoft.AzureKeyVaultSecretsProvider --name akvsecretsprovider
```

Validate the extension installation

```bash
az k8s-extension show --cluster-type connectedClusters --cluster-name <<cluster name>> --resource-group <<resource group>> --name akvsecretsprovider
```

### Create or Select an Azure Key Vault

```bash
az keyvault create -n <<cluster name>> -g <<resource group>> -l eastus
az keyvault secret set --vault-name <<cluster name>> -n DemoSecret --value MyExampleSecret
```

### Provide identity to access Azure Key Vault

Currently, the Secrets Store CSI Driver on Arc-enabled clusters can be accessed through a service principal. Follow the steps below to provide an identity that can access your Key Vault.

Use the provided Service Principal credentials provided with the lab and create a secret in ARO cluster

```bash
oc create secret generic secrets-store-creds --from-literal clientid="<client-id>" --from-literal clientsecret="<client-secret>"
oc label secret secrets-store-creds secrets-store.csi.k8s.io/used=true
```

Create a SecretProviderClass with the following YAML, filling in your values for key vault name, tenant ID, and objects to retrieve from your AKV instance

```bash
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: akvprovider-demo
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    keyvaultName: <key-vault-name>
    objects:  |
      array:
        - |
          objectName: DemoSecret
          objectType: secret            
          objectVersion: ""              
    tenantId: <tenant-Id>                
```

Create a pod with the following YAML, filling in the name of your identity

```bash
kind: Pod
apiVersion: v1
metadata:
  name: busybox-secrets-store-inline
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
```

### Validate the secrets
After the pod starts, the mounted content at the volume path specified in your deployment YAML is available.

```bash
## show secrets held in secrets-store
oc exec busybox-secrets-store-inline -- ls /mnt/secrets-store/

## print a test secret 'DemoSecret' held in secrets-store
oc exec busybox-secrets-store-inline -- cat /mnt/secrets-store/DemoSecret
```
