# Create an ARO Cluster

During this workshop, you will be working on a cluster that you will create yourself in this step. This cluster will be dedicated to you. Each person has been assigned a workshop user ID, if you need a user ID please see a facilitator.

The first step we need to do is assign an environment variable to this user ID. All the Azure resources that you will be creating will be placed in a resource group that matches this user ID.  The user ID will be in the following format: user-x. For example user-1.

While in the Azure Cloud Shell that you should still have open from the "Environment Setup" section, run the following command:

```bash
  echo 'export USERID=<user id you were given>' >> ~/.bashrc && source ~/.bashrc
```

for example if you were given user-8 as your user id you would enter:

```bash
  echo 'export USERID=user-8' >> ~/.bashrc && source ~/.bashrc
```
* Note: we are adding the environment variable to .bashrc as the cloud shell times out every 20 minutes.  Adding it to .bashrc preserves the variable throughout the workshop.

# Get a Red Hat pull secret
The next step is to get a Red Hat pull secret for your ARO cluster.  This pull secret will give you permissions to deploy ARO and access to Red Hat's Operator Hub among things.

```bash
wget https://rh-mobb.github.io/aro-hackathon-content/assets/pull-secrets/pullsecret.txt
```

### Networking

Before we can create an ARO cluster, we need to setup the virtual network that the cluster will use. First, we'll create an Azure vNet with two subnets. 

1. Create virtual network (vNet)

    ```bash
    az network vnet create \
      --address-prefixes 10.0.0.0/22 \
      --name "$USERID-aro-vnet-eastus" \
      --resource-group $USERID
    ```

2. Create control plane subnet

    ```bash
    az network vnet subnet create \
      --resource-group $USERID \
      --vnet-name "$USERID-aro-vnet-eastus" \
      --name "$USERID-aro-control-subnet-eastus" \
      --address-prefixes 10.0.0.0/23 \
      --service-endpoints Microsoft.ContainerRegistry
    ```

3. Create machine subnet

    ```bash
    az network vnet subnet create \
      --resource-group $USERID \
      --vnet-name "$USERID-aro-vnet-eastus" \
      --name "$USERID-aro-machine-subnet-eastus" \
      --address-prefixes 10.0.2.0/23 \
      --service-endpoints Microsoft.ContainerRegistry
    ```

4. Disable network policies on the control plane subnet

    > This is required for the service to be able to connect to and manage the cluster.

    ```bash
    az network vnet subnet update \
      --name "$USERID-aro-control-subnet-eastus" \
      --resource-group $USERID \
      --vnet-name "$USERID-aro-vnet-eastus" \
      --disable-private-link-service-network-policies true
    ```

5. Disable network policies on the machine subnet

    > This is required to create a private link service that we will use to connect front door later in the workshop.

    ```bash
    az network vnet subnet update \
      --name "$USERID-aro-machine-subnet-eastus" \
      --resource-group $USERID \
      --vnet-name "$USERID-aro-vnet-eastus" \
      --disable-private-link-service-network-policies true
    ```


6. Create the cluster

    > This will take between 30 and 45 minutes.

    ```bash
    az aro create \
      --resource-group $USERID \
      --name $USERID \
      --vnet "$USERID-aro-vnet-eastus" \
      --master-subnet "$USERID-aro-control-subnet-eastus" \
      --worker-subnet "$USERID-aro-machine-subnet-eastus" \
      --pull-secret @pullsecret.txt
    ```

    While the cluster is being created, let's learn more about what you will be doing in this workshop.