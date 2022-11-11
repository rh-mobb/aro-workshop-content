## Deploy Azure Service Operator

Azure Service Operator (ASO) is an open-source project by Microsoft Azure. ASO gives you the ability to provision and manage Azure resources such as compute, databases, resource groups, networking, etc. as objects in Kubernetes using declarative Kubernetes manifests.

!!! warn
    Azure Service Operator is in its second incarnation (v2) and is in Tech Preview, this means it is not fully operizationalized into Operator Hub and should not be used for Production. However it's really nifty and we like it.

ASO consists of:

- Custom Resource Definitions (CRDs) for each of the Azure services that a Kubernetes user can provision.
- A Kubernetes controller that manages the Azure resources represented by the user-specified Custom Resources. The controller attempts to synchronize the desired state in the user-specified Custom Resource with the actual state of that resource in Azure, creating it if it doesn't exist, updating it if it has been changed, or deleting it.

![Azure-Service-operator](../assets/images/aso-schematic.png)

We will deploy ASO on an ARO cluster to provision and manage Azure resources. To install ASO we need:

- An Azure Service Principal with Contributor permissions in the Azure Subscription. An Azure service principal is an identity created for use with applications, hosted services, and automated tools to access Azure resources. **This will be provided to you by the event staff**

- A cert-manager operator instance. ASO relies on having the CRDs provided by cert-manager so it can request self-signed certificates. By default, cert-manager creates an Issuer of type SelfSigned, so it will work for ASO out-of-the-box.

###  Install and run ASO on your ARO cluster

#### Install Cert Manager Operator

The cert-manager operator can easily be installed from the OpenShift Console OperatorHub. To install cert-manager, navigate to Operators > OperatorHub from the OpenShift console and search for `cert-manager`:

!!! info
    When installing Operators there are sometimes multiple versions of the same (or similar) Operators, you should always install the Red Hat provided operator (with the `Red Hat` label and the text `provided by Red Hat`)

![operator-hub](../assets/images/operator-hub-cert-manager.png)

Click on the cert-manager tile to show the details page, and follow the install prompts (accept all the default settings):

![cert-manager-details](../assets/images/cert-manager-install-1.png)

![cert-manager-details](../assets/images/cert-manager-install-2.png)



#### Prepare your environment

Create a service principal for ASO to use

```bash
az ad sp create-for-rbac --display-name "aso"
```

First, set the required environment variables for your environment, be sure to replace the ClientID and Client Secret with the values you were provided, and set the correct Resource Group and Cluster Name:

```bash
AZURE_TENANT_ID="$(az account show -o tsv --query tenantId)"
AZURE_SUBSCRIPTION_ID="$(az account show -o tsv --query id)"
CLUSTER_NAME="${AZ_ARO}"
AZURE_RESOURCE_GROUP="${AZ_RG}"
AZURE_CLIENT_ID="$(az ad sp list --show-mine --query "[0].{id:appId}" -o tsv)"
AZURE_CLIENT_SECRET=$(az ad app credential reset --id $AZURE_CLIENT_ID --append -o tsv --query {password:password})
```


#### Install the latest ASOv2 Helm Chart

```bash
helm repo add aso2 \
  https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm repo update
helm upgrade --install --devel aso2 aso2/azure-service-operator \
  --create-namespace \
  --namespace=azureserviceoperator-system \
  --set azureSubscriptionID=$AZURE_SUBSCRIPTION_ID \
  --set azureTenantID=$AZURE_TENANT_ID \
  --set azureClientID=$AZURE_CLIENT_ID \
  --set azureClientSecret=$AZURE_CLIENT_SECRET
```

You should see the following output immediately:

```bash
Release "aso2" has been upgraded. Happy Helming!
NAME: aso2
LAST DEPLOYED: Thu Nov  3 12:57:15 2022
NAMESPACE: azureserviceoperator-system
STATUS: deployed
REVISION: 4
TEST SUITE: None
```

!!! info
    It takes up to 5 min for ASO operator to be up and running

There is a pod in the azureserviceoperator-system namespace with two containers, when both are running the controller is installed and ready:

```bash
oc -n azureserviceoperator-system get pod
```

```bash
NAME                                                READY   STATUS    RESTARTS   AGE
azureserviceoperator-controller-manager-5b4bfc59df-lfpqf   2/2     Running   0          24s
```
