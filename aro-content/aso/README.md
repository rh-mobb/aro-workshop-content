## Deploy Database for Minesweeper application ASO
Azure Service Operator(ASO) is an open-source project by Microsoft Azure. ASO gives you the ability to provision and manages Azure resources within the Kubernetes plane by using familiar Kubernetes tooling and primitives. ASO consists of:
1. Custom Resource Definitions (CRDs) for each of the Azure services that a Kubernetes user can provision.
2. A Kubernetes controller that manages the Azure resources represented by the user-specified Custom Resources. The controller attempts to synchronize the desired state in the user-specified Custom Resource with the actual state of that resource in Azure, creating it if it doesn't exist, updating it if it has been changed, or deleting it.

In this workshop, we use ASO to provision a PostgreSQL DB and connect applications to Azure resources from within Kubernetes

### Prerequisites

* an ARO cluster

* oc cli

  
  

### Install and run ASO on your ARO OpenShift cluster

**create an Azure Service Principal to grant ASO permissions to create resources in your subscription**
```
 #!/bin/sh

AZURE_TENANT_ID="$(az account show -o tsv --query tenantId)"
echo "Azure Tenant ID $AZURE_TENANT_ID"
AZURE_SUBSCRIPTION_ID="$(az account show -o tsv --query id)"
echo "Azure subscription ID $AZURE_SUBSCRIPTION_ID"
export IDENTITY_CLIENT_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} > --query clientId -otsv)"
export IDENTITY_RESOURCE_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} > --query id -otsv)"
AZURE_SP="$(az ad sp create-for-rbac -n mhs-aso-hack --role contributor \ --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID -o json )"
echo " Azure SP ID/SECRET $AZURE_SP"
AZURE_CLIENT_ID="$(echo $AZURE_SP | jq -r '.appId')"
echo "SP ID $AZURE_CLIENT_ID"
AZURE_CLIENT_SECRET="$(echo $AZURE_SP | jq -r '.password')"
echo "SP SECRET $AZURE_CLIENT_SECRET"
```

 **create a secret for ASO** 
```
cat <<EOF | oc apply -f - 
apiVersion: v1
kind: Secret
metadata:
  name: azureoperatorsettings
  namespace: openshift-operators
stringData:
  AZURE_TENANT_ID: $AZURE_TENANT_ID
  AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID
  AZURE_CLIENT_ID: $AZURE_CLIENT_ID
  AZURE_CLIENT_SECRET: $AZURE_CLIENT_SECRET
#  AZURE_CLOUD_ENV: AzureCloud
EOF
```

**install cer-manager operator**

```
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: openshift-cert-manager-operator
spec:
  channel: tech-preview
  installPlanApproval: Automatic
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: openshift-cert-manager.v1.7.1
EOF
```
**deploy ASO v2 on ARO cluster**
```
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm upgrade --install --devel aso2 aso2/azure-service-operator \
     --create-namespace \
     --namespace=azureserviceoperator-system \
     --set azureSubscriptionID=$AZURE_SUBSCRIPTION_ID \
     --set azureTenantID=$AZURE_TENANT_ID \
     --set azureClientID=$AZURE_CLIENT_ID \
     --set azureClientSecret=$AZURE_CLIENT_SECRET
```

## Provision DB for Minesweeper APP

to provision a PostgreSQL DB you need to create a the following object in your cluster:
 - ResourceGroup  
 - FlexibleServer  
 - FlexibleServersDatabase 
 - FlexibleServersFirewallRule

1. **ResourceGroup**  **(if you don't. have Resource Group)**
```
cat <<EOF | oc apply -f -
apiVersion: resources.azure.com/v1beta20200601
kind: ResourceGroup
metadata:
  name: wksp-rg
  namespace: default
spec:
  location: eastus
EOF
```
2. **Provision a  PostgreSQL flexible server**

      create a secret for DB server
```
cat <<EOF | oc apply -f -
apiVersion : v1
kind : Secret
metadata : 
  name : server-admin-pw
  namespace : default
  stringData : 
   password : aGFja2F0aG9uUGFzcw== 
EOF
```
      
   create DB server
      
 ```
 cat <<EOF | oc apply -f -
 apiVersion: dbforpostgresql.azure.com/v1beta20210601
kind: FlexibleServer
metadata:
  name: wksp-pqslserver
  namespace: default
spec:
  location: eastus
  owner:
    name: wksp-rg
  version: "13"
  sku:
    name: Standard_B1ms
    tier: Burstable
  administratorLogin: myAdmin
  administratorLoginPassword: # This is the name/key of a Kubernetes secret in the same namespace
    name: server-admin-pw
    key: password
  storage:
    storageSizeGB: 32
 ```

create Server configuration
```
cat  <<EOF | oc apply -f -
apiVersion: dbforpostgresql.azure.com/v1beta20210601
kind: FlexibleServersConfiguration
metadata:
  name: pgaudit
  namespace: default
spec:
  owner:
    name: wksp-pqslserver
  azureName: pgaudit.log
  source: user-override
  value: READ
EOF
```
create database 
```
cat  <<EOF | oc apply -f -
apiVersion: dbforpostgresql.azure.com/v1beta20210601
kind: FlexibleServersDatabase
metadata:
  name: wksp-db
  namespace: default
spec:
  owner:
    name: wksp-pqslserver
  charset: utf8
EOF
```
create firewall rule for database
```
cat  <<EOF | oc apply -f -
apiVersion: dbforpostgresql.azure.com/v1beta20210601
kind: FlexibleServersFirewallRule
metadata:
  name: wksp-fw-rule
  namespace: default
spec:
  owner:
    name: wksp-pqslserver
  startIpAddress: 0.0.0.0
  endIpAddress: 255.255.255.255
EOF
```

 
