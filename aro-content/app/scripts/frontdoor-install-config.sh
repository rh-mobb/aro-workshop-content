# Below steps must be executed from a system with connectivity to the cluster
# usage: ./frontdoor-install-config.sh <resource group> <Azure Region> <User Name>
export ARORG=$1
export AROCLUSTER=$2
export USER=$3

VNET_NAME=$(az network vnet list -g $ARORG --query '[0].name' -o tsv)
PRIVATEENDPOINTSUBNET_PREFIX=10.1.5.0/24
PRIVATEENDPOINTSUBNET_NAME='PrivateEndpoint-subnet'
UNIQUE=$RANDOM
AFD_NAME=$UNIQUE-afd
ARO_RGNAME=$(az aro show -n $AROCLUSTER -g $ARORG --query "clusterProfile.resourceGroupId" -o tsv | sed 's/.*\///')
LOCATION=$(az aro show --name $AROCLUSTER --resource-group $ARORG --query location -o tsv)
WORKER_SUBNET_NAME=$(az aro show --name $AROCLUSTER --resource-group $ARORG --query 'workerProfiles[0].subnetId' -o tsv | sed 's/.*\///')
WORKER_SUBNET_ID=$(az aro show --name $AROCLUSTER --resource-group $ARORG --query 'workerProfiles[0].subnetId' -o tsv)
privatelink_id=$(az network private-link-service show -n $AROCLUSTER-pls -g $ARORG --query 'id' -o tsv)
INTERNAL_LBNAME=$(az network lb list --resource-group $ARO_RGNAME --query "[? contains(name, 'internal')].name" -o tsv)
LBCONFIG_ID=$(az network lb frontend-ip list -g $ARO_RGNAME --lb-name $INTERNAL_LBNAME --query "[? contains(subnet.id,'$WORKER_SUBNET_ID')].id" -o tsv)
LBCONFIG_IP=$(az network lb frontend-ip list -g $ARO_RGNAME --lb-name $INTERNAL_LBNAME --query "[? contains(subnet.id,'$WORKER_SUBNET_ID')].privateIpAddress" -o tsv)
DNS_RG=mobb-dns
TOP_DOMAIN=azure.mobb.ninja
DOMAIN=$USER.azure.mobb.ninja
ARO_APP_FQDN=minesweeper.$USER.azure.mobb.ninja
AFD_MINE_CUSTOM_DOMAIN_NAME=minesweeper-$USER-azure-mobb-ninja

# Create a private link service targeting the worker subnets

az network private-link-service create \
--name $AROCLUSTER-pls \
--resource-group $ARORG \
--private-ip-address-version IPv4 \
--private-ip-allocation-method Dynamic \
--vnet-name $VNET_NAME \
--subnet $WORKER_SUBNET_NAME \
--lb-frontend-ip-configs $LBCONFIG_ID

# Create a Azure Database for PostgreSQL servers service
az afd profile create \
--resource-group $ARORG \
--profile-name $AFD_NAME \
--sku Premium_AzureFrontDoor

afd_id=$(az afd profile show -g $ARORG --profile-name $AFD_NAME --query 'id' -o tsv)

# Create an endpoint for the ARO Internal Load Balancer

az afd endpoint create \
--resource-group $ARORG \
--enabled-state Enabled \
--endpoint-name 'aro-ilb'$UNIQUEID \
--profile-name $AFD_NAME

# Create a Front Door Origin Group that will point to the ARO Internal Loadbalancer
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

# Create a Front Door Origin with the above Origin Group that will point to the ARO Internal Loadbalancer

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

# Approve the private link connection

privatelink_pe_id=$(az network private-link-service show -n $AROCLUSTER-pls -g $ARORG --query 'privateEndpointConnections[0].id' -o tsv)

az network private-endpoint-connection approve \
--description 'Approved' \
--id $privatelink_pe_id

# Add your custom domain to Azure Front Door

az afd custom-domain create \
--certificate-type ManagedCertificate \
--custom-domain-name $AFD_MINE_CUSTOM_DOMAIN_NAME \
--host-name $ARO_APP_FQDN \
--minimum-tls-version TLS12 \
--profile-name $AFD_NAME \
--resource-group $ARORG

# Create an Azure Front Door endpoint for your custom domain

az afd endpoint create \
--resource-group $ARORG \
--enabled-state Enabled \
--endpoint-name 'aro-mine-'$UNIQUEID \
--profile-name $AFD_NAME

# Add an Azure Front Door route for your custom domain

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

# Update DNS

# Get a validation token from Front Door so Front Door can validate your domain

afdToken=$(az afd custom-domain show \
--resource-group $ARORG \
--profile-name $AFD_NAME \
--custom-domain-name $AFD_MINE_CUSTOM_DOMAIN_NAME \
--query "validationProperties.validationToken")

# Need an existing 'top level' domain
# Add a workshop user domain
# kmobb.com = top level domain
# parent-name = top level domain
# workshop-user.<top level domain>
TOP_DOMAIN=azure.mobb.ninja
DOMAIN=$USER.azure.mobb.ninja
ARO_APP_FQDN=minesweeper.$USER.azure.mobb.ninja
AFD_MINE_CUSTOM_DOMAIN_NAME=minesweeper-$USER-azure-mobb-ninja

az network dns zone create --name $DOMAIN --resource-group $DNS_RG --parent-name $TOP_DOMAIN

# Update Azure nameservers to match the top level domain with the new workshop user domain
for i in $(az network dns zone show -g $DNS_RG -n $TOP_DOMAIN --query "nameServers" -o tsv)
do
az network dns record-set ns add-record -g $DNS_RG -z $DOMAIN -d $i -n @
done

#Create a new text record in your DNS server

az network dns record-set txt add-record -g $DNS_RG -z $DOMAIN -n _dnsauth.$(echo $ARO_APP_FQDN | sed 's/\..*//') --value $afdToken --record-set-name _dnsauth.$(echo $ARO_APP_FQDN | sed 's/\..*//')
# Check if the domain has been validated:
# Note this can take several hours Your FQDN will not resolve until Front Door validates your domain.

az afd custom-domain list -g $ARORG --profile-name $AFD_NAME --query "[? contains(hostName, '$ARO_APP_FQDN')].domainValidationState"

# Add a CNAME record to DNS

# Get the Azure Front Door endpoint:

afdEndpoint=$(az afd endpoint show -g $ARORG --profile-name $AFD_NAME --endpoint-name aro-mine-$UNIQUEID --query "hostName" -o tsv)

# Create a cname record for the application

az network dns record-set cname set-record -g $DNS_RG -z $DOMAIN \
 -n $(echo $ARO_APP_FQDN | sed 's/\..*//') -z $DOMAIN -c $afdEndpoint

 # Delete Route
oc delete route microsweeper-appservice

 # Create new route
cat << EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  labels:
    app.kubernetes.io/name: microsweeper-appservice
    app.kubernetes.io/version: 1.0.0-SNAPSHOT
    app.openshift.io/runtime: quarkus
  name: microsweeper-appservice
  namespace: minesweeper
spec:
  host: $ARO_APP_FQDN
  to:
    kind: Service
    name: microsweeper-appservice
    weight: 100
    targetPort:
      port: 8080
  wildcardPolicy: None
EOF