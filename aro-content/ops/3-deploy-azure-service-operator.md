## Deploy Azure Service Operator
Azure Service Operator(ASO) is an open-source project by Microsoft Azure. ASO gives you the ability to provision and manages Azure resources within the Kubernetes plane by using familiar Kubernetes tooling and primitives. ASO consists of:
1. Custom Resource Definitions (CRDs) for each of the Azure services that a Kubernetes user can provision.
2. A Kubernetes controller that manages the Azure resources represented by the user-specified Custom Resources. The controller attempts to synchronize the desired state in the user-specified Custom Resource with the actual state of that resource in Azure, creating it if it doesn't exist, updating it if it has been changed, or deleting it.


### Prerequisites

* an ARO cluster

* oc cli

* jq

* helm

* logged in to ARO cluster

*  optional: client tool for Postgres - psql , pgadmin

###  Install and run ASO on your ARO OpenShift cluster


**create an Azure Service Principal to grant ASO permissions to create resources in your subscription**
```
 #!/bin/sh

AZURE_TENANT_ID="$(az account show -o tsv --query tenantId)"
echo "Azure Tenant ID $AZURE_TENANT_ID"
AZURE_SUBSCRIPTION_ID="$(az account show -o tsv --query id)"
echo "Azure subscription ID $AZURE_SUBSCRIPTION_ID"
#export IDENTITY_CLIENT_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} > --query clientId -otsv)"
#export IDENTITY_RESOURCE_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} > --query id -otsv)"
AZURE_SP="$(az ad sp create-for-rbac -n mhs-aso-hack --role contributor  --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID -o json )"
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

**install cert-manager operator**

**create Namespace for cert-manager-operator**
```
cat <<EOF | oc apply -f -
kind: Namespace
apiVersion: v1
metadata:
  name: openshift-cert-manager-operator
EOF
```

**create operator group**

```
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-cert-manager-operator-group
  namespace: openshift-cert-manager-operator
spec: {}  
EOF
```
**create subscription**

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

**wait for cert-manager operator to be up and running**

```
while [[ $(oc get pods -l app=cert-manager -n openshift-cert-manager -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for cert-manager pod" && sleep 1; done

while [[ $(oc get pods -l app=webhook -n openshift-cert-manager -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for cert-manager webhook pod" && sleep 1; done
```


**deploy ASO **v2 on **the **ARO**** cluster****
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
**Note: issuing certificate takes up to 5 min for ASO operator.**
