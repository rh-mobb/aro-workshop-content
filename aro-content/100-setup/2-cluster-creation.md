# Create an ARO Cluster

While in the Azure Cloud Shell that you should still have open from the "Environment Setup" section, run the following command to ensure the system has the correct environment variables for your user (If not, request help):

```bash
env | grep -E  'AZ_'
```

You should see something like the following, if not make sure you ran `. ~/.workshoprc` in the earlier steps.

```{.text .no-copy}
AZ_USER=username
AZ_RG=username-rg
AZ_ARO=username-cluster
AZ_LOCATION=eastus
```

### Resource Group and Networking

{% if redhat_led %}
Ordinarily you would need to create a Resource Group and Virtual Networking for your ARO cluster.  However for the workshop this has already been done for you. However you should verify that they are created and ready for you to use.

1. Verify virtual network (vNet)

    ```bash
    az network vnet show \
      --name "${AZ_USER}-vnet" \
      --resource-group "${AZ_RG}" | jq .name
    ```

2. Verify control plane subnet

    ```bash
    az network vnet subnet show \
      --resource-group "${AZ_RG}" \
      --vnet-name "${AZ_USER}-vnet" \
      --name "${AZ_USER}-cp-subnet" | jq .name
    ```

3. Verify machine subnet

    ```bash
    az network vnet subnet show \
      --resource-group "${AZ_RG}" \
      --vnet-name "${AZ_USER}-vnet" \
      --name "${AZ_USER}-machine-subnet" | jq .name
    ```

{% else %}
Before we can create an ARO cluster, we need to setup the resource group and virtual network that the cluster will use.

1. Create the resource group

    ```bash
    az group create \
      --resource-group "${AZ_RG}" \
      --location "${AZ_LOCATION}"
    ```

1. Create virtual network (vNet)

    ```bash
    az network vnet create \
      --name "${AZ_USER}-vnet" \
      --resource-group "${AZ_RG}"
    ```

2. Create control plane subnet

    ```bash
    az network vnet subnet create \
      --resource-group "${AZ_RG}" \
      --vnet-name "${AZ_USER}-vnet" \
      --name "${AZ_USER}-cp-subnet" \
      --address-prefixes 10.0.0.0/23 \
      --service-endpoints Microsoft.ContainerRegistry
    ```

3. Create machine subnet

    ```bash
    az network vnet subnet create \
      --resource-group "${AZ_RG}" \
      --vnet-name "${AZ_USER}-vnet" \
      --name "${AZ_USER}-machine-subnet" \
      --address-prefixes 10.0.2.0/23 \
      --service-endpoints Microsoft.ContainerRegistry
    ```

1. Update the machine subnet to disable private link service network policies (this allows Azure to manage the cluster over a privatelink)

    ```bash
    az network vnet subnet update \
      --resource-group "${AZ_RG}" \
      --vnet-name "${AZ_USER}-vnet" \
      --name "${AZ_USER}-machine-subnet" \
      --disable-private-link-service-network-policies true
    ```
{% endif %}


{% if not precreated_clusters %}

1. Check what versions of ARO are available

    ```bash
    ARO_VERSION=$(az aro get-versions --location "${AZ_LOCATION}" \
      --query "[?contains(@,'{{ aro_version }}')]" --output tsv)
    echo "${ARO_VERSION}"
    ```


6. Create the cluster

    !!! warning "Don't forget to update the pull secret location if its not in the default location. This command will take between 30 and 45 minutes."

    ```bash
    az aro create \
      --resource-group "${AZ_RG}" \
      --name "${AZ_ARO}" \
      --vnet "${AZ_USER}-vnet" \
      --master-subnet "${AZ_USER}-cp-subnet" \
      --worker-subnet "${AZ_USER}-machine-subnet" \
      --version "${ARO_VERSION}" \
{%- if redhat_led %}
      --pull-secret @~/clouddrive/pullsecret.txt
{%- else %}
      --pull-secret @{{ workshop_dir }}/pull-secret.txt
{% endif %}
    ```

    While the cluster is being created, let's learn more about what you will be doing in this workshop.
{% else %}

1. The ARO cluster has been pre-created for you.  Please skip to the next section to verify access.
{% endif %}
