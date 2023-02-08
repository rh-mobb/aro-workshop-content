# Introduction

[Azure Arc](https://azure.microsoft.com/en-us/products/azure-arc/){:target="_blank"} is a bridge that extends the Azure platform to help you build applications and services on top of Azure Red Hat OpenShift. In this section of the workshop, we will integrate our ARO cluster with Azure Arc. When you connect an OpenShift cluster with Azure Arc, it will:

- Be represented in Azure Resource Manager with a unique ID
- Receive tags just like any other Azure resource

Azure Arc for OpenShift supports the following use cases for connected clusters:

- Deploy applications and apply configuration using GitOps-based configuration management.
- View and monitor your clusters using Azure Monitor for containers.
- Enforce threat protection using Microsoft Defender for Kubernetes.
- Apply policy definitions using Azure Policy for Kubernetes.

## Connect Azure Arc with your ARO cluster

1. First, we need to connect our ARO cluster to Azure Arc. To do so, run the following command. 

    ```bash
    az connectedk8s connect --resource-group "${AZ_RG}" --name "${AZ_ARO}" \
      --distribution openshift --infrastructure auto
    ```

    This command takes about 5 minutes to complete. Once completed, your output will look something like this: 

    ```json
    [...]
    "infrastructure": "azure",
    "kubernetesVersion": null,
    "lastConnectivityTime": null,
    "location": "{{ azure_region }}",
    "managedIdentityCertificateExpirationTime": null,
    "name": "user1-cluster",
    "offering": null,
    "provisioningState": "Succeeded",
    "resourceGroup": "user1-rg",
    [...]
    ```

    Your cluster will also be visible in the Azure Portal under the *Kubernetes - Azure Arc* blade. 

1. Next, we need to grant elevated permissions to the Azure Arc service account. To do so, run the following command:

    ```bash
    oc adm policy add-scc-to-user privileged \
      system:serviceaccount:azure-arc:azure-arc-kube-aad-proxy-sa
    ```

1. In order for the permissions to take effect we need to restart the `kube-aad-proxy` deployment. To do so, run the following command: 

    ```bash
    oc -n azure-arc rollout restart deployment kube-aad-proxy
    ```

1. After a few moments, run the following command to see the various Azure Arc pods running:

    ```bash
    oc -n azure-arc get pods
    ```

    Your output will look very similar to:

    ```bash
    NAME                                         READY   STATUS    RESTARTS   AGE
    cluster-metadata-operator-77895ddcd7-56v5h   2/2     Running   0          8m18s
    clusterconnect-agent-84dff79cd9-zpwd2        3/3     Running   0          8m18s
    clusteridentityoperator-67c69db6db-h2wgb     2/2     Running   0          8m18s
    config-agent-5f4b45884c-b9gv7                2/2     Running   0          8m18s
    controller-manager-8565bfd849-bk58z          2/2     Running   0          8m18s
    extension-manager-5bddf75868-rqlxx           2/2     Running   0          8m18s
    flux-logs-agent-576bfc88c6-t56ht             1/1     Running   0          8m18s
    kube-aad-proxy-6457f7966-jbzz2               2/2     Running   0          8m18s
    kube-aad-proxy-69869fd7f6-6x9xq              1/2     Running   0          10s
    metrics-agent-5467b679bf-l2r8c               2/2     Running   0          8m18s
    resource-sync-agent-6c67b5d58-bzbxt          2/2     Running   0          8m18s
    ```

1. Next, let's check the status of the cluster from Azure Arc. To do so, run the following command: 

    ```bash 
    az connectedk8s list --resource-group ${AZ_RG} --output table
    ```

    Your output will look very similar to:

    ```bash
    Name           Location    ResourceGroup
    -------------  ----------  ---------------
    user1-cluster  {{ azure_region }}      user1-rg
    ```