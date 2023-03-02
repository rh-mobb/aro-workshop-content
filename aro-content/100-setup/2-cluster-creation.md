# Create an ARO Cluster

During this workshop, you will be working on a cluster that you will create yourself in this step. This cluster will be dedicated to you. Each person has been assigned a workshop user ID, if you need a user ID please see a facilitator.

The first step we need to do is assign an environment variable to this user ID. All the Azure resources that you will be creating will be placed in a resource group that matches this user ID.  The user ID will be in the following format: userX. For example user1.

While in the Azure Cloud Shell that you should still have open from the "Environment Setup" section, run the following command to ensure the system has the correct environment variables for your user (If not, request help):

```bash
env | grep -E  'AZ_'
```
<!--
# Get a Red Hat pull secret

The next step is to get a Red Hat pull secret for your ARO cluster.  This pull secret will give you permissions to deploy ARO and access to Red Hat's Operator Hub among things.

1. Login to [https://console.redhat.com/openshift/downloads#tool-pull-secret](https://console.redhat.com/openshift/downloads#tool-pull-secret) using the credentials provided to you.

2. hit the `Copy` button.

3. Create an Environment variable for the pull secret (replace `<paste>` with the contents of your clipboard)

    ```bash
    echo '<paste>' > pullsecret.txt
    ```
-->

### Networking

Before we can create an ARO cluster, we need to setup the virtual network that the cluster will use. Due to accout access restrictions these have been created for you.

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
      --vnet "${AZ_USER}-vnet" \
      --master-subnet "${AZ_USER}-cp-subnet" \
      --worker-subnet "${AZ_USER}-machine-subnet" \
      --pull-secret @~/clouddrive/pullsecret.txt
    ```

    While the cluster is being created, let's learn more about what you will be doing in this workshop.
