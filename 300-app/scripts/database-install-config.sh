# Below steps must be executed from a system with connectivity to the cluster
# usage: ./database-install-config.sh <resource group> <Azure Region>
export ARORG=$1
export LOCATION=$2
export VNETRG=$3
export USER=$4

VNET_NAME=$(az network vnet list -g $VNETRG --query '[0].name' -o tsv)
PRIVATEENDPOINTSUBNET_PREFIX=10.1.5.0/24
PRIVATEENDPOINTSUBNET_NAME="$USER-PrivateEndpoint-subnet"
UNIQUEID=$RANDOM
POSTGRES_SERVER_NAME=${USER}-microsweeper-database
# Create a Azure Database for PostgreSQL servers service
az postgres server create --name ${USER}-microsweeper-database --resource-group $ARORG --location $LOCATION --admin-user quarkus --admin-password r3dh4t1! --sku-name GP_Gen5_2

POSTGRES_ID=$(az postgres server show -n $POSTGRES_SERVER_NAME -g $ARORG --query 'id' -o tsv)

# Create a private endpoint connection for the database
az network vnet subnet create \
--resource-group $VNETRG \
--vnet-name $VNET_NAME \
--name $PRIVATEENDPOINTSUBNET_NAME \
--address-prefixes $PRIVATEENDPOINTSUBNET_PREFIX \
--disable-private-endpoint-network-policies true

az network private-endpoint create \
--name ${USER}postgresPvtEndpoint' \
--resource-group $VNETRG \
--vnet-name $VNET_NAME \
--subnet $PRIVATEENDPOINTSUBNET_NAME \
--private-connection-resource-id $POSTGRES_ID \
--group-id '${USER}postgresqlServer' \
--connection-name 'postgresdbConnection'

# Create and configure a private DNS Zone for the Postgres database
az network private-dns zone create \
--resource-group $ARORG \
--name '${USER}privatelink.postgres.database.azure.com'

az network private-dns link vnet create \
--resource-group $ARORG \
--zone-name '${USER}privatelink.postgres.database.azure.com' \
--name '${USER}PostgresDNSLink' \
--virtual-network $VNET_NAME \
--registration-enabled false

az network private-endpoint dns-zone-group create \
--resource-group $ARORG \
--name '${USER}PostgresDb-ZoneGroup' \
--endpoint-name '${USER}postgresPvtEndpoint' \
--private-dns-zone '${USER}privatelink.postgres.database.azure.com' \
--zone-name '${USER}postgresqlServer'

NETWORK_INTERFACE_ID=$(az network private-endpoint show --name '${USER}'postgresPvtEndpoint --resource-group $VNETRG --query 'networkInterfaces[0].id' -o tsv)

POSTGRES_IP=$(az resource show --ids $NETWORK_INTERFACE_ID --api-version 2019-04-01 --query 'properties.ipConfigurations[0].properties.privateIPAddress' -o tsv)

az network private-dns record-set a create --name $UNIQUEID-'${USER}-microsweeper-database --zone-name ${USER}privatelink.postgres.database.azure.com --resource-group $ARORG  

az network private-dns record-set a add-record --record-set-name $UNIQUEID-${USER}-microsweeper-database --zone-name ${USER}privatelink.postgres.database.azure.com --resource-group $ARORG -a $POSTGRES_IP

#Create a postgres database that will contain scores for the minesweeper application
az postgres db create \
--resource-group $ARORG \
--name ${USER}-score \
--server-name ${USER}-microsweeper-database

echo $POSTGRES_IP