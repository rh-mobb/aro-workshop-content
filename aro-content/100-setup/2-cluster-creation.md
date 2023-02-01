# Create an ARO Cluster

During this workshop, you will be working on a cluster that you will create yourself in this step. This cluster will be dedicated to you. Each person has been assigned a workshop user ID, if you need a user ID please see a facilitator.

The first step we need to do is assign an environment variable to this user ID. All the Azure resources that you will be creating will be placed in a resource group that matches this user ID.  The user ID will be in the following format: user-x. For example user-1.

While in the Azure Cloud Shell that you should still have open from the "Environment Setup" section, run the following command to ensure the system has the correct environment variables for your user (If not, request help):

```bash
env | grep -E  'AZ_'
```

# Get a Red Hat pull secret

The next step is to get a Red Hat pull secret for your ARO cluster.  This pull secret will give you permissions to deploy ARO and access to Red Hat's Operator Hub among things.

1. Login to [https://console.redhat.com/openshift/downloads#tool-pull-secret](https://console.redhat.com/openshift/downloads#tool-pull-secret) . If you don't have an account yet, it is good a time to create it. ;)

2. hit the `Copy` button.

3. Create an Environment variable for the pull secret (replace `<paste>` with the contents of your clipboard)

    ```bash
    echo '<paste>' > pullsecret.txt
    ```


### Networking

Before we can create an ARO cluster, we need to setup the virtual network that the cluster will use. Due to accout access restrictions these have been created for you.

0. Resource group and VNET creation
    ```bash
    export AZ_USER=$(az ad signed-in-user show --query "userPrincipalName" -o tsv | cut -d @ -f1)

    AZR_RESOURCE_LOCATION=eastus
    
    AZ_RG=${USER}-openshift
    
    AZR_RESOURCE_GROUP=${USER}-openshift
    
    AZ_ARO=${USER}-cluster
    
    AZR_ARO_VNET_PREFIXES=10.0.0.0/21
    
    AZR_ARO_SUBNET_MASTER_PREFIXES=10.0.0.0/23
    
    AZR_ARO_SUBNET_WORKER_PREFIXES=10.0.2.0/23

    echo "----> Create resource group"
    az group create --name $AZ_RG --location $AZR_RESOURCE_LOCATION

    echo "----> Create virtual network"
    az network vnet create \
    --address-prefixes $AZR_ARO_VNET_PREFIXES \
    --name "${AZ_USER}-vnet" \
    --resource-group $AZ_RG

   echo "----> Create control plane subnet"
   az network vnet subnet create \
   --resource-group $AZ_RG \
   --vnet-name "${AZ_USER}-vnet" \
   --name "${AZ_USER}-cp-subnet" \
   --address-prefixes $AZR_ARO_SUBNET_MASTER_PREFIXES \
   --service-endpoints Microsoft.ContainerRegistry

   echo "----> Create machine subnet subnet"
   az network vnet subnet create \
   --resource-group $AZ_RG \
   --vnet-name "${AZ_USER}-vnet" \
   --name "${AZ_USER}-machine-subnet" \
   --address-prefixes $AZR_ARO_SUBNET_WORKER_PREFIXES \
   --service-endpoints Microsoft.ContainerRegistry

   echo "----> Update control plane subnet to disable private link service network policies"
   az network vnet subnet update \
   --name "${AZ_USER}-cp-subnet" \
   --resource-group $AZ_RG \
   --vnet-name "${AZ_USER}-vnet" \
   --disable-private-link-service-network-policies true

    ```

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

6. Create the cluster

    > This will take between 30 and 45 minutes.

    ```bash
    az aro create \
      --resource-group "${AZ_RG}" \
      --name "${AZ_ARO}" \
      --debug \
      --vnet "${AZ_USER}-vnet" \
      --master-subnet "${AZ_USER}-cp-subnet" \
      --worker-subnet "${AZ_USER}-machine-subnet" \
      --pull-secret @~/pull-secret
    ```

    While the cluster is being created, let's learn more about what you will be doing in this workshop.

7. Once the cluster is ready, fetch credentials, API URL, and Console URL

    ```bash
    cat << EOF >> ~/.workshoprc
    export OCP_PASS=$(az aro list-credentials --name \
      "${AZ_ARO}" --resource-group "${AZ_RG}" \
      --query="kubeadminPassword" -o tsv)
    export OCP_USER="kubeadmin"
    export OCP_CONSOLE="$(az aro show --name ${AZ_ARO} \
      --resource-group ${AZ_RG} \
      -o tsv --query consoleProfile)"
    export OCP_API="$(az aro show --name ${AZ_ARO} \
      --resource-group ${AZ_RG} \
      --query apiserverProfile.url -o tsv)"
    EOF
    source ~/.workshoprc
    ```
