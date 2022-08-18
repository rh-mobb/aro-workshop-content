#!/bin/bash

set -ex
uniqueId=$RANDOM
AZR_RESOURCE_LOCATION=eastus
AZR_RESOURCE_GROUP=hackathon-$uniqueId
AZR_CLUSTER=hackathon-openshift-$uniqueId
#AZR_PULL_SECRET=/app/pull-secret.txt
AZR_PULL_SECRET=~/Downloads/pull-secret.txt
NETWORK_SUBNET=10.1.0.0/20
CONTROL_SUBNET=10.1.0.0/24
MACHINE_SUBNET=10.1.1.0/24
FIREWALL_SUBNET=10.1.2.0/24
JUMPHOST_SUBNET=10.1.3.0/24
GATEWAY_SUBNET=10.1.4.0/24

VPN_PREFIX=172.18.0.0/24
caCert=$(openssl x509 -in ~/Downloads/easy-rsa-3.1.0/easyrsa3/pki/ca.crt -outform der | base64)

echo "==> Create Infrastructure"
# az login --service-principal -u e9601a92-6993-4692-bd23-98cdce3ac9b4 -p 9dy8Q~ZriOX8adUVbTweJnR.Ed9DTyOMMos3OcLS --tenant 64dc69e4-d083-49fc-9569-ebece1dd1408
# az config set extension.use_dynamic_install=yes_without_prompt

echo "----> Create resource group"
az group create \
  --name $AZR_RESOURCE_GROUP \
  --location $AZR_RESOURCE_LOCATION

echo "----> Create virtual network"
az network vnet create \
  --address-prefixes $NETWORK_SUBNET \
  --name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
  --resource-group $AZR_RESOURCE_GROUP

echo "----> Create control plane subnet"
az network vnet subnet create \
   --resource-group $AZR_RESOURCE_GROUP \
   --vnet-name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
   --name "$AZR_CLUSTER-aro-control-subnet-$AZR_RESOURCE_LOCATION" \
   --address-prefixes $CONTROL_SUBNET \
   --disable-private-link-service-network-policies true \
   --service-endpoints Microsoft.ContainerRegistry

echo "----> Create virtual network gateway subnet"
az network vnet subnet create \
  --vnet-name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
  -n GatewaySubnet \
  -g $AZR_RESOURCE_GROUP \
  --address-prefix $GATEWAY_SUBNET 

echo "----> Create machine subnet subnet"
az network vnet subnet create \
   --resource-group $AZR_RESOURCE_GROUP \
   --vnet-name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
   --name "$AZR_CLUSTER-aro-machine-subnet-$AZR_RESOURCE_LOCATION" \
   --address-prefixes $MACHINE_SUBNET \
   --disable-private-link-service-network-policies true \
   --service-endpoints Microsoft.ContainerRegistry

az network vnet subnet update                                       \
   --name "$AZR_CLUSTER-aro-control-subnet-$AZR_RESOURCE_LOCATION"   \
   --resource-group $AZR_RESOURCE_GROUP                              \
   --vnet-name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION"        \
   --disable-private-link-service-network-policies true

#az aro create \
#   --resource-group $AZR_RESOURCE_GROUP \
#   --name $AZR_CLUSTER \
#   --vnet "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
#   --master-subnet "$AZR_CLUSTER-aro-control-subnet-$AZR_RESOURCE_LOCATION" \
#   --worker-subnet "$AZR_CLUSTER-aro-machine-subnet-$AZR_RESOURCE_LOCATION" \
#   --apiserver-visibility Private \
#   --ingress-visibility Private \
#   --pull-secret @$AZR_PULL_SECRET

echo "==> Create cluster"
az aro create \
   --resource-group $AZR_RESOURCE_GROUP \
   --name $AZR_CLUSTER \
   --vnet "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
   --master-subnet "$AZR_CLUSTER-aro-control-subnet-$AZR_RESOURCE_LOCATION" \
   --worker-subnet "$AZR_CLUSTER-aro-machine-subnet-$AZR_RESOURCE_LOCATION" \
   --apiserver-visibility Private \
   --ingress-visibility Private \
   --pull-secret @$AZR_PULL_SECRET

az aro show \
   --name $AZR_CLUSTER \
   --resource-group $AZR_RESOURCE_GROUP \
   -o tsv --query consoleProfile

az aro list-credentials \
   --name $AZR_CLUSTER \
   --resource-group $AZR_RESOURCE_GROUP \
   -o tsv


echo "==> Configure firewall"

echo "----> Create firewall subnet"
az network vnet subnet create \
 -g $AZR_RESOURCE_GROUP \
 --vnet-name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION" \
 -n "AzureFirewallSubnet" \
 --address-prefixes $FIREWALL_SUBNET

az network public-ip create -g $AZR_RESOURCE_GROUP -n fw-ip \
  --sku "Standard" --location $AZR_RESOURCE_LOCATION

echo "----> create firewall"
az network firewall create -g $AZR_RESOURCE_GROUP \
  -n aro-private -l $AZR_RESOURCE_LOCATION \
  --enable-dns-proxy true

az network firewall ip-config create -g $AZR_RESOURCE_GROUP \
  -f aro-private -n fw-config --public-ip-address fw-ip \
     --vnet-name "$AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION"

az network firewall update \
  --name aro-private \
  --resource-group $AZR_RESOURCE_GROUP

FWPUBLIC_IP=$(az network public-ip show -g $AZR_RESOURCE_GROUP -n fw-ip --query "ipAddress" -o tsv)
FWPRIVATE_IP=$(az network firewall show -g $AZR_RESOURCE_GROUP -n aro-private --query "ipConfigurations[0].privateIpAddress" -o tsv)

echo "----> Create route table"
az network route-table create -g $AZR_RESOURCE_GROUP --name aro-udr \
-l $AZR_RESOURCE_LOCATION
sleep 10


echo "----> Configure route tables"
az network route-table route create -g $AZR_RESOURCE_GROUP --name aro-udr \
--route-table-name aro-udr --address-prefix 0.0.0.0/0 \
--next-hop-type VirtualAppliance --next-hop-ip-address $FWPRIVATE_IP

az network route-table route create -g $AZR_RESOURCE_GROUP --name aro-vnet \
--route-table-name aro-udr --address-prefix 10.1.0.0/16 --name local-route \
--next-hop-type VirtualNetworkGateway


az network firewall network-rule create -g $AZR_RESOURCE_GROUP -f aro-private \
      --collection-name 'allow-https' --name allow-all \
      --action allow --priority 100 \
      --source-addresses '*' --dest-addr '*' \
      --protocols 'Any' --destination-ports '1-65535'

az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'allow-all' \
  --protocols Http=80 Https=443 \
  --target-fqdns '*' \
  --source-addresses '*' \
  --name 'allow-all' \
  --priority 200 \
  --action Allow 

  az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'Minimum-Required-FQDN' \
  --protocols Http=80 Https=443 \
  --target-fqdns arosvc.eastus.data.azurecr.io \*.quay.io registry.redhat.io mirror.openshift.com api.openshift.com arosvc.azurecr.io management.azure.com login.microsoftonline.com gcs.prod.monitoring.core.windows.net \*.blob.core.windows.net \*.servicebus.windows.net \*.table.core.windows.net \
  --source-addresses '*' \
  --name minimum_required_group_target_fqdns \
  --priority 201 \
  --action Allow

  az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'Aro-required-urls' \
  --protocols Http=80 Https=443 \
  --target-fqdns quay.io registry.redhat.io sso.redhat.com openshift.org \
  --source-addresses '*' \
  --name first_group_target_fqdns \
  --priority 202 \
  --action Allow

  az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'Telemetry-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns cert-api.access.redhat.com api.access.redhat.com infogw.api.openshift.com cloud.redhat.com \
  --source-addresses '*' \
  --name second_group_target_fqdns \
  --priority 203 \
  --action Allow

az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'Cloud-APIs' \
  --protocols Http=80 Https=443 \
  --target-fqdns management.azure.com \
  --source-addresses '*' \
  --name third_group_target_fqdns \
  --priority 204 \
  --action Allow

az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'OpenShift-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns mirror.openshift.com storage.googleapis.com api.openshift.com registry.access.redhat.com \
  --source-addresses '*' \
  --name fourth_group_target_fqdns \
  --priority 205 \
  --action Allow

az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'Monitoring-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns login.microsoftonline.com gcs.prod.monitoring.core.windows.net \*.blob.core.windows.net \*.servicebus.windows.net \*.table.core.windows.net\
  --source-addresses '*' \
  --name fifth_group_target_fqdns \
  --priority 206 \
  --action Allow

az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'Arc-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns eastus.login.microsoft.com management.azure.com eastus.dp.kubernetesconfiguration.azure.com login.microsoftonline.com login.windows.net mcr.microsoft.com \*.data.mcr.microsoft.com gbl.his.arc.azure.com \*.his.arc.azure.com \*.servicebus.windows.net guestnotificationservice.azure.com \*.guestnotificationservice.azure.com sts.windows.net k8connecthelm.azureedge.net \
  --source-addresses '*' \
  --name sixth_group_target_fqdns \
  --priority 207 \
  --action Allow

az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'Arc-ContainerInsights-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns \*.ods.opinsights.azure.com \*.oms.opinsights.azure.com dc.services.visualstudio.com \*.monitoring.azure.com login.microsoftonline.com \
  --source-addresses '*' \
  --name seventh_group_target_fqdns \
  --priority 208 \
  --action Allow

az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'Docker-HUB-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns registry.hub.docker.com \*.docker.io production.cloudflare.docker.com auth.docker.io \*.gcr.io \
  --source-addresses '*' \
  --name eighth_group_target_fqdns \
  --priority 209 \
  --action Allow

az network firewall application-rule create \
  --firewall-name aro-private \
  --resource-group $AZR_RESOURCE_GROUP \
  --collection-name 'Miscellaneous-URLs' \
  --protocols Http=80 Https=443 \
  --target-fqdns quayio-production-s3.s3.amazonaws.com \
  --source-addresses '*' \
  --name nineth_group_target_fqdns \
  --priority 210 \
  --action Allow

az network vnet subnet update -g $AZR_RESOURCE_GROUP \
  --vnet-name $AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION \
  --name "$AZR_CLUSTER-aro-control-subnet-$AZR_RESOURCE_LOCATION" \
  --route-table aro-udr

az network vnet subnet update -g $AZR_RESOURCE_GROUP \
  --vnet-name $AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION \
  --name "$AZR_CLUSTER-aro-machine-subnet-$AZR_RESOURCE_LOCATION" \
  --route-table aro-udr

az network vnet subnet update -g $AZR_RESOURCE_GROUP \
  --vnet-name $AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION \
  --name "$AZR_CLUSTER-aro-control-subnet-$AZR_RESOURCE_LOCATION" \
  --route-table aro-udr

az network vnet subnet update -g $AZR_RESOURCE_GROUP \
  --vnet-name $AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION \
  --name "$AZR_CLUSTER-aro-machine-subnet-$AZR_RESOURCE_LOCATION" \
  --route-table aro-udr

echo "==> Create VPN"


az network public-ip create \
  -n hackaton-pip-$uniqueId \
  -g $AZR_RESOURCE_GROUP \
  --allocation-method Static \
  --sku Standard \
  --zone 1 2 3

pip=$(az network public-ip show -g $AZR_RESOURCE_GROUP --name hackaton-pip-$uniqueId --query "ipAddress" -o tsv)

az network vnet-gateway create \
  --name  hackaton-GW \
  --location $AZR_RESOURCE_LOCATION \
  --public-ip-address hackaton-pip-$uniqueId \
  --resource-group $AZR_RESOURCE_GROUP \
  --vnet $AZR_CLUSTER-aro-vnet-$AZR_RESOURCE_LOCATION \
  --gateway-type Vpn \
  --sku VpnGw3AZ \
  --address-prefixes $VPN_PREFIX \
  --root-cert-data $caCert \
  --root-cert-name hackaton-p2s \
  --vpn-type RouteBased \
  --vpn-gateway-generation Generation2 \
  --client-protocol IkeV2 OpenVPN \
  --no-wait

echo "==> Post Install Steps"

