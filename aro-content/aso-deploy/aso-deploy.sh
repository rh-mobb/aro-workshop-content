#!/bin/sh
AZURE_TENANT_ID="$(az account show -o tsv --query tenantId)"
echo "Azure Tenant ID $AZURE_TENANT_ID"
AZURE_SUBSCRIPTION_ID="$(az account show -o tsv --query id)"
echo "Azure subscription ID $AZURE_SUBSCRIPTION_ID"

# az ad sp create-for-rbac -n "azure-service-operator" --role contributor \
#     --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID
# Creat Service Principal

# export IDENTITY_CLIENT_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} --query clientId -otsv)"
# export IDENTITY_RESOURCE_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} --query id -otsv)"
AZURE_SP="$(az ad sp create-for-rbac -n mhs-aso-hack --role contributor \
 --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID -o json )"

 echo " Azure SP ID/SECRET $AZURE_SP"
AZURE_CLIENT_ID="$(echo $AZURE_SP | jq -r '.appId')"
echo "SP ID $AZURE_CLIENT_ID"
AZURE_CLIENT_SECRET="$(echo $AZURE_SP | jq -r '.password')"
echo "SP SECRET $AZURE_CLIENT_SECRET"

#

cat <<EOF |oc apply -f - 
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



cat <<EOF | oc apply -f -
kind: Namespace
apiVersion: v1
metadata:
  name: openshift-cert-manager-operator
EOF


cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-cert-manager-operator-group
  namespace: openshift-cert-manager-operator
spec: {}  
EOF

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

helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm upgrade --install --devel aso2 aso2/azure-service-operator \
     --create-namespace \
     --namespace=azureserviceoperator-system \
     --set azureSubscriptionID=$AZURE_SUBSCRIPTION_ID \
     --set azureTenantID=$AZURE_TENANT_ID \
     --set azureClientID=$AZURE_CLIENT_ID \
     --set azureClientSecret=$AZURE_CLIENT_SECRET