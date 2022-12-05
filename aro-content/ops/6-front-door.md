## Install and Configure Azure Front Door for our Application

The first step is to export three environment variables for the Resource Group ARO is in, the ARO Cluster name, both of which are the same as the USERID.  We will set these variables for readability purposes.

```bash
echo 'export ARORG=$USERID' >> ~/.bashrc && source ~/.bashrc
echo 'export AROCLUSTER=$USERID' >> ~/.bashrc && source ~/.bashrc

```

Next we, need to get the name of the VNET ARO is in

```bash
echo "export VNET_NAME=$(az network vnet list -g $ARORG --query '[0].name' -o tsv)" >> ~/.bashrc && source ~/.bashrc
```

Provide a subnet prefix for the private link subnet.  This subnet will contain the private link service we will use to connect Front Door with ARO.

```bash
echo "export PRIVATEENDPOINTSUBNET_PREFIX=10.0.5.0/24" >> ~/.bashrc && source ~/.bashrc
```

Give the private link subnet a meaningful name

```bash
echo "export PRIVATEENDPOINTSUBNET_NAME=PrivateEndpoint-subnet" >> ~/.bashrc && source ~/.bashrc
```

Create a unique random number so we don't create services with the same name

```bash
echo "export UNIQUE=$RANDOM" >> ~/.bashrc && source ~/.bashrc
```

Provide a unique name for the Azure Front Door Service we will create

```bash
echo "export AFD_NAME=$UNIQUE-afd" >> ~/.bashrc && source ~/.bashrc
```

Get the ARO Cluster Resource Group name.  Note this the name of the resource group that the ARO service creates and manages.  This is the resource group that contains all the VMs, Storage, Load Balancers, etc that ARO manages.

```bash
echo "export ARO_RGNAME=$(az aro show -n $AROCLUSTER -g $ARORG --query 'clusterProfile.resourceGroupId' -o tsv | sed 's/.*\///')" >> ~/.bashrc && source ~/.bashrc
```

Get the Azure location of the ARO cluster

```bash
echo "export LOCATION=$(az aro show --name $AROCLUSTER --resource-group $ARORG --query location -o tsv)" >> ~/.bashrc && source ~/.bashrc
```

Get the workers nodes subnet name and IDs so we can connect the Azure Front Door to the workers nodes using a private link service.
```bash
echo "export WORKER_SUBNET_NAME=$(az aro show --name $AROCLUSTER --resource-group $ARORG --query 'workerProfiles[0].subnetId' -o tsv | sed 's/.*\///')" >> ~/.bashrc && source ~/.bashrc

echo "export WORKER_SUBNET_ID=$(az aro show --name $AROCLUSTER --resource-group $ARORG --query 'workerProfiles[0].subnetId' -o tsv)" >> ~/.bashrc && source ~/.bashrc
# privatelink_id=$(az network private-link-service show -n $AROCLUSTER-pls -g $ARORG --query 'id' -o tsv)
```

Get the internal load balancer name, id and ip that the private link service will be connected to.

```bash
echo "export INTERNAL_LBNAME=$(az network lb list --resource-group $ARO_RGNAME --query "[? contains(name, 'internal')].name" -o tsv)" >> ~/.bashrc && source ~/.bashrc

export LBCONFIG_ID=$(az network lb frontend-ip list -g $ARO_RGNAME --lb-name $INTERNAL_LBNAME --query "[? contains(subnet.id,'$WORKER_SUBNET_ID')].id" -o tsv)
export LBCONFIG_IP=$(az network lb frontend-ip list -g $ARO_RGNAME --lb-name $INTERNAL_LBNAME --query "[? contains(subnet.id,'$WORKER_SUBNET_ID')].privateIpAddress" -o tsv)

```

Set the following DNS variables for the workshop so we can add DNS records to the azure.mobb.cloud domain

```bash
DNS_RG=shared-services
TOP_DOMAIN=ws.mobb.cloud
```

Set user specific domain settings.  We will be creating a new DNS zone with the DOMAIN variable.
ARO_APP_FQDN is the fully qualified url for your ratingsapp application
ARO_MINE_CUSTOM_DOMAIN_NAME is the name of the DNS entry.

```bash
DOMAIN=$USERID.ws.mobb.cloud
echo "export ARO_APP_FQDN=ratingsapp.$USERID.ws.mobb.cloud" >> ~/.bashrc && source ~/.bashrc
AFD_RATINGS_CUSTOM_DOMAIN_NAME=ratingsapp-$USERID-ws-mobb-cloud
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

privatelink_id=$(az network private-link-service show -n $AROCLUSTER-pls -g $ARORG --query 'id' -o tsv)
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
--custom-domain-name $AFD_RATINGS_CUSTOM_DOMAIN_NAME \
--host-name $ARO_APP_FQDN \
--minimum-tls-version TLS12 \
--profile-name $AFD_NAME \
--resource-group $ARORG
```
*Note: This takes about 5 minutes


Add an Azure Front Door route for your custom domain

```bash
az afd route create \
--endpoint-name 'aro-ilb'$UNIQUEID \
--forwarding-protocol HttpOnly \
--https-redirect Enabled \
--origin-group 'afdorigin' \
--profile-name $AFD_NAME \
--resource-group $ARORG \
--route-name 'aro-ratings-route' \
--supported-protocols Http Https \
--patterns-to-match '/*' \
--custom-domains $AFD_RATINGS_CUSTOM_DOMAIN_NAME
```

#### Update DNS
Now that we have Front Door setup and configured, we need to setup DNS to work with the front door endpoint.

Get a validation token from Front Door so Front Door can validate your domain

```bash
afdToken=$(az afd custom-domain show \
--resource-group $ARORG \
--profile-name $AFD_NAME \
--custom-domain-name $AFD_RATINGS_CUSTOM_DOMAIN_NAME \
--query "validationProperties.validationToken")
```


Update Azure nameservers to match the top level domain with the new workshop user domain

```bash
for i in $(az network dns zone show -g $DNS_RG -n $TOP_DOMAIN --query "nameServers" -o tsv)
do
az network dns record-set ns add-record -g $USERID -z $DOMAIN -d $i -n @
done
```

Create a new text record in your DNS server

```bash
az network dns record-set txt add-record -g $USERID -z $DOMAIN -n _dnsauth.$(echo $ARO_APP_FQDN | sed 's/\..*//') --value $afdToken --record-set-name _dnsauth.$(echo $ARO_APP_FQDN | sed 's/\..*//')
```

Check if the domain has been validated:
*Note this would be a great time to take a break and grab a coffee ... it can take several minutes for Azure Front Door to validate your domain.

```
az afd custom-domain list -g $ARORG --profile-name $AFD_NAME --query "[? contains(hostName, '$ARO_APP_FQDN')].domainValidationState"
```

Get the Azure Front Door endpoint:

```bash
afdEndpoint=$(az afd endpoint show -g $ARORG --profile-name $AFD_NAME --endpoint-name aro-ilb$UNIQUEID --query "hostName" -o tsv)
```


Create a cname record for the application

```bash
az network dns record-set cname set-record -g $USERID -z $DOMAIN \
 -n $(echo $ARO_APP_FQDN | sed 's/\..*//') -z $DOMAIN -c $afdEndpoint
```

### Congratations!!
If you made it this far and setup Front Door yourself, pat yourself on the back.
