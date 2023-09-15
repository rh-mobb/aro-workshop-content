# Below steps must be executed from a system with connectivity to the cluster
# usage: ./post-install-add.sh <resource group> <cluster name>
export AZR_RESOURCE_GROUP=$1
export AZR_CLUSTER=$2
# AAD Integration for RBAC: https://docs.microsoft.com/en-us/azure/openshift/configure-azure-ad-cli
domain=$(az aro show -g $AZR_RESOURCE_GROUP -n $AZR_CLUSTER --query clusterProfile.domain -o tsv)
location=$(az aro show -g $AZR_RESOURCE_GROUP -n $AZR_CLUSTER --query location -o tsv)
apiServer=$(az aro show -g $AZR_RESOURCE_GROUP -n $AZR_CLUSTER --query apiserverProfile.url -o tsv)
webConsole=$(az aro show -g $AZR_RESOURCE_GROUP -n $AZR_CLUSTER --query consoleProfile.url -o tsv)

oauthCallbackURL=https://oauth-openshift.apps.$domain.$location.aroapp.io/oauth2callback/AAD
# Generate a random number for client secret
let randomNum=$(($RANDOM*$RANDOM))
uniqueId=randomNum
client_secret=FTAaro@Hack$randomNum

# Create an Azure Active Directory application and retrieve the created application identifier.
app_id=$(az ad app create \
  --query appId -o tsv \
  --display-name "fta-aro-auth-1-$uniqueId" \
  --optional-claims @manifest.json \
  --web-redirect-uris $oauthCallbackURL)

client_secret=$(az ad app credential reset --query password -o tsv --id $app_id)

# Retrieve the tenant ID of the subscription that owns the application.
tenant_id=$(az account show --query tenantId -o tsv)

# Create a manifest.json file to configure the Azure Active Directory application.
cat > manifest.json<< EOF
{"idToken":[{
  "name": "upn",
  "source": null,
  "essential": false,
  "additionalProperties": []
},
{
"name": "email",
  "source": null,
  "essential": false,
  "additionalProperties": []
}]}
EOF

# Update the Azure Active Directory application's optionalClaims with a manifest
az ad app update \
  --set optionalClaims.idToken=@manifest.json \
  --id $app_id

# Add permission for the Azure Active Directory Graph.User.Read scope to enable sign in and read user profile.
az ad app permission add \
 --api 00000002-0000-0000-c000-000000000000 \
 --api-permissions 311a71cc-e848-46a1-bdf8-97ff7156d8e6=Scope \
 --id $app_id

# Connect using the OpenShift CLI
apiServer=$(az aro show -g $AZR_RESOURCE_GROUP -n $AZR_CLUSTER --query apiserverProfile.url -o tsv)

# Retrieve the kubeadmin credentials. Run the following command to find the password for the kubeadmin user.
kubeadmin_password=$(az aro list-credentials --name $AZR_CLUSTER --resource-group $AZR_RESOURCE_GROUP --query kubeadminPassword --output tsv)

# Log in to the OpenShift cluster's API server using the following command.
oc login $apiServer -u kubeadmin -p $kubeadmin_password

# Create an OpenShift secret to store the Azure Active Directory application secret.
oc create secret generic openid-client-secret-azuread --namespace openshift-config --from-literal=clientSecret=$client_secret

cat > oidc.yaml<< EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: AAD
    mappingMethod: claim
    type: OpenID
    openID:
      clientID: $app_id
      clientSecret:
        name: openid-client-secret-azuread
      extraScopes:
      - email
      - profile
      extraAuthorizeParameters:
        include_granted_scopes: "true"
      claims:
        preferredUsername:
        - email
        - upn
        name:
        - name
        email:
        - email
      issuer: https://login.microsoftonline.com/$tenant_id
EOF

# Apply the configuration to the cluster.
oc apply -f oidc.yaml

# Optional step to test sign in using AAD: Add cluster-admin rolebinding to one of the AAD user
# Example: oc create clusterrolebinding umarm-cluster-admin-role --clusterrole=cluster-admin --user=umarm@microsoft.com
oc create clusterrolebinding kevcolli-admin --clusterrole=cluster-admin --user=kevcolli@redhat.com

# Go to OpenShift Web Console, now you will see Log in option with AAD
# Using AAD option, sign in with the user who we provided cluster-admin role in the previous step
