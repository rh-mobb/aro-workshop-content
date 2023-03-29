# Configuring Azure AD for Cluster authentication
<!-- taken from here - https://mobb.ninja/docs/idp/azuread-aro-cli/ -->

!!! warning "In order to complete these steps you need permission to create Azure AD Applications, and other Administrative level permissions. If you do not have Admin access in your Azure tenant, you may want to skip this section. If you're not sure you can proceed, if you get any errors, again, just move on to the next section."

Your Azure Red Hat OpenShift (ARO) cluster has a built-in OAuth server. Developers and administrators do not really directly interact with the OAuth server itself, but instead interact with an external identity provider (such as Azure AD) which is brokered by the OAuth server in the cluster. To learn more about cluster authentication, visit the [Red Hat documentation for identity provider configuration](https://docs.openshift.com/container-platform/latest/authentication/understanding-identity-provider.html){:target="_blank"} and the [Microsoft documentation for configuring Azure Active Directory authentication for ARO](https://learn.microsoft.com/en-us/azure/openshift/configure-azure-ad-cli){:target="_blank"}.

In this section of the workshop, we'll configure Azure AD as the cluster identity provider in Azure Red Hat OpenShift.

## Configure our Azure AD application

1. First, we need to determine the OAuth callback URL, which we will use to tell Azure AD where it should send authentication responses. To do so, run the following command:

    ```bash
    IDP_CALLBACK="https://oauth-openshift.apps.$(az \
      aro show -g ${AZ_RG} -n ${AZ_ARO} --query clusterProfile.domain \
      -o tsv).${AZ_LOCATION}.aroapp.io/oauth2callback/AAD"
    echo "${IDP_CALLBACK}"
    ```

1. Next, let's create a manifest file to configure the AAD application. To do so, run the following command:

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

1. Next, let's use the manifest we created above to create an Azure AD App for your cluster. To do so, run the following command:

    ```bash
    az ad app create \
      --display-name ${AZ_USER}-idp \
      --web-redirect-uris ${IDP_CALLBACK} \
      --sign-in-audience AzureADMyOrg \
      --optional-claims @manifest.json
    APPID=$(az ad app list --display-name ${AZ_USER}-idp --query "[].appId" -o tsv)
    ```

1. To allow us to securely sign our authentication requests, we need to create an Azure Service Principal and grab the credentials to authenticate with. To do so, run the following command:

    ```bash
    az ad sp create --id ${APPID}
    az ad sp update --id ${APPID} --set 'tags=["WindowsAzureActiveDirectoryIntegratedApp"]'
    IDP_SECRET=$(az ad app credential reset --id ${APPID} --query password -o tsv)
    ```

1. Next, we need to add permissions to our Azure AD application which grants `read email`, `read profile`, and `read user`. To do so, run the following command:

    ```bash
    az ad app permission add \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions 64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0=Scope \
    --id ${APPID}
    az ad app permission add \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions 14dad69e-099b-42c9-810b-d002981feec1=Scope \
    --id ${APPID}
    az ad app permission add \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope \
    --id ${APPID}
    ```

    !!! warning "If you see the output `Invoking az ad app permission grant --id xxxxxxx --api 00000003-0000-0000-c000-000000000000 is needed to make the change effective` you can safely ignore it."

## Configure our OpenShift cluster to use Azure AD

1. Create an secret to store the service principal secret, above. To do so, run the following command:

    ```bash
    oc create secret generic openid-client-secret-azuread \
    -n openshift-config \
    --from-literal=clientSecret="${IDP_SECRET}"
    ```

1. Next, let's update the OAuth server's custom resource with our Azure AD configuration.

    ```bash
    AZ_TENANT=$(az account show --query tenantId -o tsv)
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
          clientID: "${APPID}"
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
          issuer: "https://login.microsoftonline.com/${AZ_TENANT}"
    EOF
    ```

    !!! note
        We are specifically requesting `email`, `upn`, and `name` optional claims from Azure AD to populate the data in our user profiles. This is entirely configurable.

    !!! warning
        If you see the output `Warning: resource oauths/cluster is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by oc apply. oc apply should only be used on resources created declaratively by either oc create --save-config or oc apply. The missing annotation will be patched automatically.` you can safely ignore it for this.

1. Next, give Cluster Admin permissions to your AAD user by running the following commands:

    ```bash
    oc adm policy add-cluster-role-to-user cluster-admin \
      $(az ad signed-in-user show --query "userPrincipalName" -o tsv)
    ```

1. Logout from your OCP Console and browse back to the Console URL (`echo $OCP_CONSOLE` if you have forgotten it) and you should see a new option to login called `AAD`. Select that, and log in using your workshop Azure credentials.

    !!! warning "If you do not see a new **AAD** login option, wait a few more minutes as this process can take a few minutes to deploy across the cluster and revisit the Console URL."
