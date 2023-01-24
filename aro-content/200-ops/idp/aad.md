# Configuring Azure AD for Cluster authentication
<!-- taken from here - https://mobb.ninja/docs/idp/azuread-aro-cli/ -->
## Configure Azure AD for OAuth

1. Determine the OAuth callback URL

    ```bash
    IDP_CALLBACK="$(az aro show -g $AZ_RG -n $AZ_ARO --query consoleProfile.url \
      -o tsv | sed 's/console-openshift-console/oauth-openshift/')oauth2callback/AAD"
    echo "${IDP_CALLBACK}"
    ```

1. Create a manifest file to configure the AAD application

    ```bash
    cat << EOF > manifest.json
    {
    "idToken": [
      {
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
      }
      ]
    }
    EOF
    ```

1. Create an Azure AD App for your cluster

    ```bash
    az ad app create \
      --display-name $AZ_USER-idp \
      --web-redirect-uris $IDP_CALLBACK \
      --sign-in-audience AzureADMyOrg \
      --optional-claims @manifest.json
    APPID=$(az ad app list --display-name $AZ_USER-idp --query [].appId -o tsv)
    ```

1. Create a Service Principal for the App

    ```bash
    az ad sp create --id $APPID
    az ad sp update --id $APPID --set 'tags=["WindowsAzureActiveDirectoryIntegratedApp"]'
    ```

1. Create the client secret

    ```bash
    IDP_SECRET=$(az ad app credential reset --id $APPID --query password -o tsv)
    ```

1. Add permissions to AAD for `read email`, `read profile`, and `read user`

    ```bash
    az ad app permission add \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions 64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0=Scope \
    --id $APPID
    az ad app permission add \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions 14dad69e-099b-42c9-810b-d002981feec1=Scope \
    --id $APPID
    az ad app permission add \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope \
    --id $APPID
    ```

    !!! warning "If you see the output `Invoking az ad app permission grant --id xxxxxxx --api 00000003-0000-0000-c000-000000000000 is needed to make the change effective` you can safely ignore it."

1. Fetch your tenant ID

    ```bash
    TENANTID=$(az account show --query tenantId -o tsv)
    ```

## Configure OpenShift for OAuth

1. Create an secret to store the application password

```bash
    oc create secret generic openid-client-secret-azuread \
      -n openshift-config \
      --from-literal=clientSecret="${IDP_SECRET}"
```

1. Apply the OpenID authentication configuration

    ```bash
    cat << EOF | oc apply -f -
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
          clientID: $APPID
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
          issuer: https://login.microsoftonline.com/$TENANTID
    EOF
    ```

1. Logout from your OCP Console and you should see a new option `AAD` select that, and log in using your workshop Azure credentials.

1. Give Cluster Admin to your AAD user (you need to have logged in above to be known to OpenShift RBAC)

```bash
oc adm policy add-cluster-role-to-user cluster-admin \
  $(az ad signed-in-user show --query "userPrincipalName" -o tsv)
```

1. Log out from Console and log back in as your Azure AD user. You should now have cluster admin rights.
