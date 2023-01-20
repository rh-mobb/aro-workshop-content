## Introduction

The [Azure Service Operator (ASO)](https://azure.github.io/azure-service-operator/){:target="_blank"} is an open-source project by Microsoft. ASO gives you the ability to provision and manage Azure resources such as compute, databases, resource groups, networking, etc. as objects in Kubernetes using declarative Kubernetes manifests.

!!! warning "Azure Service Operator is currently in BETA"

    Azure Service Operator is in its second incarnation (v2) and is in beta. This means ASO is not fully supported and should not be used in production. In addition, at this time, ASO is not available in OperatorHub and has to be installed using Helm or raw manifests. We are using it in this workshop as a demonstration.

ASO consists of:

- Custom Resource Definitions (CRDs) for each of the Azure services that a Kubernetes user can provision.
- A Kubernetes controller that manages the Azure resources represented by the user-specified Custom Resources. The controller attempts to synchronize the desired state in the user-specified Custom Resource with the actual state of that resource in Azure, creating it if it doesn't exist, updating it if it has been changed, or deleting it.

  ![Azure-Service-operator](/assets/images/aso-schematic.png)

We will deploy ASO on an ARO cluster to provision and manage Azure resources. To install ASO we need:

- An Azure Service Principal with Contributor permissions in the Azure Subscription. An Azure Service Principal is an identity created for use with applications, hosted services, and automated tools to access Azure resources. This has been pre-created for you as a part of the workshop.

- A cert-manager instance. ASO needs cert-manager to programmatically create self-signed certificates.

## Install and configure the Azure Service Operator (ASO)

### Install the Cert Manager Operator

The cert-manager operator can easily be installed from the OpenShift Console OperatorHub.

1. Return to your tab with the OpenShift Web Console. If you need to reauthenticate, follow the steps in the [Access Your Cluster](../setup/3-access-cluster/) section.

1. Using the menu on the left Select *Operators* -> *OperatorHub*.

    ![Web Console - OperatorHub Sidebar](/assets/images/web-console-operatorhub-menu.png){ align=center }

1. In the search box, search for "cert-manager" and click on the *cert-manager Operator for Red Hat OpenShift* box that has the Red Hat logo.

    ![Web Console - Cert Manager Operator Selection](/assets/images/web-console-cert-manager-operator-selection.png){ align=center }

1. Click on *Install* on the page that appears.

    ![Web Console - Cert Manager Simple Install](/assets/images/web-console-cert-manager-simple-install.png){ align=center }

1. Accept the defaults that are presented and select *Install* to install the operator.

    ![Web Console - Cert Manager Detailed Install](/assets/images/web-console-cert-manager-detailed-install.png){ align=center }

1. Allow the operator a few minutes to successfully install the cert-manager operator into the cluster.

    ![Web Console - Cert Manager Successful Install](/assets/images/web-console-cert-manager-successful-install.png){ align=center }


### Install the Azure Service Operator (ASO)

1. First, let's get the necessary information for the Azure Service Operator to authenticate against Azure. To do so, run the following command:

    ```bash
    export AZURE_TENANT_ID="$(az account show -o tsv --query tenantId)"
    echo "Tenant ID: ${AZURE_TENANT_ID}"
    export AZURE_SUBSCRIPTION_ID="$(az account show -o tsv --query id)"
    echo "Subscription ID: ${AZURE_SUBSCRIPTION_ID}"
    export AZURE_CLIENT_ID="$(oc get secret azure-credentials -n kube-system -o json | jq -r .data.azure_client_id | base64 --decode)"
    echo "Client ID: ${AZURE_CLIENT_ID}"
    export AZURE_CLIENT_SECRET="$(oc get secret azure-credentials -n kube-system -o json | jq -r .data.azure_client_secret | base64 --decode)"
    echo "Secret (Sensitive Information): ${AZURE_CLIENT_SECRET}"
    ```

2. Next, let's install the latest Azure Service Operator (v2) using the Helm Chart that Microsoft provides. To do so, run the following command:

    ```bash
    helm repo add aso2 \
      https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
    helm repo update
    helm upgrade --install --devel aso2 aso2/azure-service-operator \
      --create-namespace \
      --namespace=azureserviceoperator-system \
      --set azureSubscriptionID="${AZURE_SUBSCRIPTION_ID}" \
      --set azureTenantID="${AZURE_TENANT_ID}" \
      --set azureClientID="${AZURE_CLIENT_ID}" \
      --set azureClientSecret="${AZURE_CLIENT_SECRET}"
    ```

    Within a minute or less, you should see output that looks similar to:

    ```bash
    "aso2" has been added to your repositories
    Hang tight while we grab the latest from your chart repositories...
    ...Successfully got an update from the "aso2" chart repository
    Update Complete. ⎈Happy Helming!⎈
    Release "aso2" does not exist. Installing it now.
    NAME: aso2
    LAST DEPLOYED: Tue Nov 15 03:07:17 2022
    NAMESPACE: azureserviceoperator-system
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    ```

    !!! info

        It takes a few minutes for the Azure Service Operator pod to be ready.

1. It takes a few minutes for the Azure Service Operator pod to become ready. To check the status of the pod, run the following command:

    ```bash
    oc -n azureserviceoperator-system get pod
    ```

    Your output should look something like this:

    ```bash
    NAME                                                      READY   STATUS    RESTARTS   AGE
    azureserviceoperator-controller-manager-76d5cf659-zznkr   2/2     Running   0          2m3s
    ```

    Once you see "2/2" and "Running", you're ready to move to the next phase of deploying resources with the Azure Service Operator.
