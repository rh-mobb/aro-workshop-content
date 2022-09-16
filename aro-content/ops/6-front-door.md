## Detailed steps and instructions.

* note - the steps below must be executed from a system with connectivity to the cluster such as the Azure Cloud Shell.

The first step is to export three environment variables for the Resource Group ARO is in, the ARO Cluster name, and your User ID.

```bash
export ARORG=(ARO Resource Group Name)
export AROCLUSTER=(ARO Cluster Name)
export USER=(Your User ID)
```

Next we, need to get the name of the VNET ARO is in

```bash
VNET_NAME=$(az network vnet list -g $ARORG --query '[0].name' -o tsv)
```

Provide a subnet prefix for the private link subnet.  This subnet will contain the private link service we will use to connect Front Door with ARO.

```bash
PRIVATEENDPOINTSUBNET_PREFIX=10.1.5.0/24
```

Give the private link subnet a meaningful name

```bash
PRIVATEENDPOINTSUBNET_NAME='PrivateEndpoint-subnet'
```

Create a unique random number so we don't create services with the same name

```bash
UNIQUE=$RANDOM
```

Provide a unique name for the Azure Front Door Service we will create

```bash
AFD_NAME=$UNIQUE-afd
```

Get the ARO Cluster Resource Group name.  Note this the name of the resource group that the ARO service creates and manages.  This is the resource group that contains all the VMs, Storage, Load Balancers, etc that ARO manages.

```bash
ARO_RGNAME=$(az aro show -n $AROCLUSTER -g $ARORG --query "clusterProfile.resourceGroupId" -o tsv | sed 's/.*\///')
```

Get the Azure location of the ARO cluster

```bash
LOCATION=$(az aro show --name $AROCLUSTER --resource-group $ARORG --query location -o tsv)
```

Get the workers nodes subnet name and IDs so we can connect the Azure Front Door to the workers nodes using a private link service.
```bash
WORKER_SUBNET_NAME=$(az aro show --name $AROCLUSTER --resource-group $ARORG --query 'workerProfiles[0].subnetId' -o tsv | sed 's/.*\///')
WORKER_SUBNET_ID=$(az aro show --name $AROCLUSTER --resource-group $ARORG --query 'workerProfiles[0].subnetId' -o tsv)
# privatelink_id=$(az network private-link-service show -n $AROCLUSTER-pls -g $ARORG --query 'id' -o tsv)
```

Get the internal load balancer name, id and ip that the private link service will be connected to.

```bash
INTERNAL_LBNAME=$(az network lb list --resource-group $ARO_RGNAME --query "[? contains(name, 'internal')].name" -o tsv)
LBCONFIG_ID=$(az network lb frontend-ip list -g $ARO_RGNAME --lb-name $INTERNAL_LBNAME --query "[? contains(subnet.id,'$WORKER_SUBNET_ID')].id" -o tsv)
LBCONFIG_IP=$(az network lb frontend-ip list -g $ARO_RGNAME --lb-name $INTERNAL_LBNAME --query "[? contains(subnet.id,'$WORKER_SUBNET_ID')].privateIpAddress" -o tsv)
```

Set the following DNS variables for the workshop so we can add DNS records to the azure.mobb.ninja domain

```bash
DNS_RG=mobb-dns
TOP_DOMAIN=azure.mobb.ninja
```

Set user specific domain settings.  We will be creating a new DNS zone with the DOMAIN variable.
ARO_APP_FQDN is the fully qualified url for your minesweeper application
ARO_MINE_CUSTOM_DOMAIN_NAME is the name of the DNS entry.

```bash
DOMAIN=$USER.azure.mobb.ninja
ARO_APP_FQDN=minesweeper.$USER.azure.mobb.ninja
AFD_MINE_CUSTOM_DOMAIN_NAME=minesweeper-$USER-azure-mobb-ninja
```

Now that we have all the required variables set, we can start creating the Front Door service and everything it needs.

#### Create a private link service targeting the worker subnets

The first thing we will create is the private link service, that again is what will provide private connectivty from Front Door to your cluster.

```bash
az network private-link-service create \
--name $AROCLUSTER-pls \
--resource-group $ARORG \
--private-ip-address-version IPv4 \
--private-ip-allocation-method Dynamic \
--vnet-name $VNET_NAME \
--subnet $WORKER_SUBNET_NAME \
--lb-frontend-ip-configs $LBCONFIG_ID
```

Create an instance of Azure Front Door and get the Front Door ID.

```bash
az afd profile create \
--resource-group $ARORG \
--profile-name $AFD_NAME \
--sku Premium_AzureFrontDoor

afd_id=$(az afd profile show -g $ARORG --profile-name $AFD_NAME --query 'id' -o tsv)
```

Create a Front Door endpoint for the ARO Internal Load Balancer.  This will allow Front Door to send traffic to the ARO Load Balancer.

```bash
az afd endpoint create \
--resource-group $ARORG \
--enabled-state Enabled \
--endpoint-name 'aro-ilb'$UNIQUEID \
--profile-name $AFD_NAME
```

Create a Front Door Origin Group that will point to the ARO Internal Loadbalancer
```bash
az afd origin-group create \
--origin-group-name 'afdorigin' \
--probe-path '/' \
--probe-protocol Http \
--probe-request-type GET \
--probe-interval-in-seconds 100 \
--profile-name $AFD_NAME \
--resource-group $ARORG \
--probe-interval-in-seconds 120 \
--sample-size 4 \
--successful-samples-required 3 \
--additional-latency-in-milliseconds 50
```

Create a Front Door Origin with the above Origin Group that will point to the ARO Internal Loadbalancer.
Click [here](https://docs.microsoft.com/en-us/azure/frontdoor/origin?pivots=front-door-standard-premium) to read more about Front Door Origins and Origin Groups.

```bash
az afd origin create \
--enable-private-link true \
--private-link-resource $privatelink_id \
--private-link-location $LOCATION \
--private-link-request-message 'Private link service from AFD' \
--weight 1000 \
--priority 1 \
--http-port 80 \
--https-port 443 \
--origin-group-name 'afdorigin' \
--enabled-state Enabled \
--host-name $LBCONFIG_IP \
--origin-name 'afdorigin' \
--profile-name $AFD_NAME \
--resource-group $ARORG
```

Approve the private link connection

```bash
privatelink_pe_id=$(az network private-link-service show -n $AROCLUSTER-pls -g $ARORG --query 'privateEndpointConnections[0].id' -o tsv)

az network private-endpoint-connection approve \
--description 'Approved' \
--id $privatelink_pe_id
```

Add your custom domain to Azure Front Door

```bash
az afd custom-domain create \
--certificate-type ManagedCertificate \
--custom-domain-name $AFD_MINE_CUSTOM_DOMAIN_NAME \
--host-name $ARO_APP_FQDN \
--minimum-tls-version TLS12 \
--profile-name $AFD_NAME \
--resource-group $ARORG
```

Create an Azure Front Door endpoint for your custom domain

```bash
az afd endpoint create \
--resource-group $ARORG \
--enabled-state Enabled \
--endpoint-name 'aro-mine-'$UNIQUEID \
--profile-name $AFD_NAME
```

Add an Azure Front Door route for your custom domain

```bash
az afd route create \
--endpoint-name 'aro-mine-'$UNIQUEID \
--forwarding-protocol HttpOnly \
--https-redirect Disabled \
--origin-group 'afdorigin' \
--profile-name $AFD_NAME \
--resource-group $ARORG \
--route-name 'aro-mine-route' \
--supported-protocols Http Https \
--patterns-to-match '/*' \
--custom-domains $AFD_MINE_CUSTOM_DOMAIN_NAME
```

#### Update DNS
Now that we have Front Door setup and configured, we need to setup DNS to work with the front door endpoint.

Get a validation token from Front Door so Front Door can validate your domain

```bash
afdToken=$(az afd custom-domain show \
--resource-group $ARORG \
--profile-name $AFD_NAME \
--custom-domain-name $AFD_MINE_CUSTOM_DOMAIN_NAME \
--query "validationProperties.validationToken")
```

Create a dns zone for your minesweeper application

```bash
az network dns zone create --name $DOMAIN --resource-group $DNS_RG --parent-name $TOP_DOMAIN
```

Update Azure nameservers to match the top level domain with the new workshop user domain

```bash
for i in $(az network dns zone show -g $DNS_RG -n $TOP_DOMAIN --query "nameServers" -o tsv)
do
az network dns record-set ns add-record -g $DNS_RG -z $DOMAIN -d $i -n @
done
```

Create a new text record in your DNS server

```bash
az network dns record-set txt add-record -g $DNS_RG -z $DOMAIN -n _dnsauth.$(echo $ARO_APP_FQDN | sed 's/\..*//') --value $afdToken --record-set-name _dnsauth.$(echo $ARO_APP_FQDN | sed 's/\..*//')
```

Check if the domain has been validated:
*Note this would be a great time to take a break and grab a coffee ... it can take several minutes for Azure Front Door to validate your domain.

```
az afd custom-domain list -g $ARORG --profile-name $AFD_NAME --query "[? contains(hostName, '$ARO_APP_FQDN')].domainValidationState"
```

Get the Azure Front Door endpoint:

```bash
afdEndpoint=$(az afd endpoint show -g $ARORG --profile-name $AFD_NAME --endpoint-name aro-mine-$UNIQUEID --query "hostName" -o tsv)
```

Create a cname record for the application

```bash
az network dns record-set cname set-record -g $DNS_RG -z $DOMAIN \
 -n $(echo $ARO_APP_FQDN | sed 's/\..*//') -z $DOMAIN -c $afdEndpoint
```

### Congratations!!
If you made it this far and setup Front Door yourself, pat yourself on the back.
