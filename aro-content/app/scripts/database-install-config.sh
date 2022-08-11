# Below steps must be executed from a system with connectivity to the cluster
# usage: ./database-install-config.sh <resource group> <Azure Region>
export ARORG=$1
export LOCATION=$2

VNET_NAME=$(az network vnet list -g $ARORG --query '[0].name' -o tsv)
PRIVATEENDPOINTSUBNET_PREFIX=10.1.5.0/24
PRIVATEENDPOINTSUBNET_NAME='PrivateEndpoint-subnet'
UNIQUEID=$RANDOM
# Create a Azure Database for PostgreSQL servers service
az postgres server create --name microsweeper-database --resource-group $ARORG --location $LOCATION --admin-user quarkus --admin-password r3dh4t1! --sku-name GP_Gen5_2

POSTGRES_ID=$(az postgres server show -n microsweeper-database -g $ARORG --query 'id' -o tsv)

# Create a private endpoint connection for the database
az network vnet subnet create \
--resource-group $ARORG \
--vnet-name $VNET_NAME \
--name $PRIVATEENDPOINTSUBNET_NAME \
--address-prefixes $PRIVATEENDPOINTSUBNET_PREFIX \
--disable-private-endpoint-network-policies true

az network private-endpoint create \
--name 'postgresPvtEndpoint' \
--resource-group $ARORG \
--vnet-name $VNET_NAME \
--subnet $PRIVATEENDPOINTSUBNET_NAME \
--private-connection-resource-id $POSTGRES_ID \
--group-id 'postgresqlServer' \
--connection-name 'postgresdbConnection'

# Create and configure a private DNS Zone for the Postgres database
az network private-dns zone create \
--resource-group $ARORG \
--name 'privatelink.postgres.database.azure.com'

az network private-dns link vnet create \
--resource-group $ARORG \
--zone-name 'privatelink.postgres.database.azure.com' \
--name 'PostgresDNSLink' \
--virtual-network $VNET_NAME \
--registration-enabled false

az network private-endpoint dns-zone-group create \
--resource-group $ARORG \
--name 'PostgresDb-ZoneGroup' \
--endpoint-name 'postgresPvtEndpoint' \
--private-dns-zone 'privatelink.postgres.database.azure.com' \
--zone-name 'postgresqlServer'

NETWORK_INTERFACE_ID=$(az network private-endpoint show --name postgresPvtEndpoint --resource-group $ARORG --query 'networkInterfaces[0].id' -o tsv)

POSTGRES_IP=$(az resource show --ids $NETWORK_INTERFACE_ID --api-version 2019-04-01 --query 'properties.ipConfigurations[0].properties.privateIPAddress' -o tsv)

az network private-dns record-set a create --name $UNIQUEID-microsweeper-database --zone-name privatelink.postgres.database.azure.com --resource-group $ARORG  

az network private-dns record-set a add-record --record-set-name $UNIQUEID-microsweeper-database --zone-name privatelink.postgres.database.azure.com --resource-group $ARORG -a $POSTGRES_IP

#Create a postgres database that will contain scores for the minesweeper application
az postgres db create \
--resource-group $ARORG \
--name score \
--server-name microsweeper-database

echo $POSTGRES_IP