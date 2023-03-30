## Configure Azure Front Door

[Azure Front Door](https://azure.microsoft.com/en-us/products/frontdoor/){:target="_blank"} is Microsoft’s Content Delivery Network (CDN) which provides a fast, reliable, and secure connection between your users and your applications’ content. Azure Front Door delivers your content using the Microsoft’s global edge network with hundreds of global and local POPs distributed around the world. Azure Front Door allows you to privately connect to your Azure Red Hat OpenShift (ARO) cluster using Azure Private Link. This helps to protect your apps from malicious actors and allows you to embrace a zero-trust access model.

1. To begin, we first need to get the name of the vNet that ARO is in. To do so, run the following command:

    ```bash
    export VNET_NAME=$(az network vnet list \
    -g ${AZ_RG} --query '[0].name' -o tsv)
    ```

1. While we have a resource group that contains the Azure Red Hat OpenShift (ARO) cluster object, the ARO service itself creates a separate resource group that is fully controlled by the ARO service. This resource group contains all the virtual machines, storage accounts, load balancers, and more that ARO needs to function. To identify that resource group, run the following command:

    ```bash
    export CLUSTER_RG=$(az aro show -n ${AZ_ARO} \
    -g ${AZ_RG} --query 'clusterProfile.resourceGroupId' -o tsv | cut -d/ -f5)
    echo "ARO Cluster RG: ${CLUSTER_RG}"
    ```

1. Since Azure Front Door connects to your Azure Red Hat OpenShift (ARO) cluster via Azure Private Link, we need to get a few pieces of information so we can configure the Private Link. To do so, run the following commands:

    ```bash
    export WORKER_SUBNET_ID=$(az aro show -n ${AZ_ARO} \
    -g ${AZ_RG} --query 'workerProfiles[0].subnetId' -o tsv)
    echo "Worker Subnet ID: ${WORKER_SUBNET_ID}"
    export INTERNAL_LBNAME=$(az network lb list -g ${CLUSTER_RG} \
    --query "[? contains(name, 'internal')].name" -o tsv)
    echo "LB Name: ${INTERNAL_LBNAME}"
    export LBCONFIG_ID=$(az network lb frontend-ip list -g ${CLUSTER_RG} \
    --lb-name ${INTERNAL_LBNAME} --query \
    "[? contains(subnet.id,'${WORKER_SUBNET_ID}')].id" -o tsv)
    echo "LB ID: ${LBCONFIG_ID}"
    export LBCONFIG_IP=$(az network lb frontend-ip list -g ${CLUSTER_RG} \
    --lb-name ${INTERNAL_LBNAME} --query \
    "[? contains(subnet.id,'${WORKER_SUBNET_ID}')].privateIpAddress" \
    -o tsv)
    echo "LB IP: ${LBCONFIG_IP}"
    ```

1. Now that we have all the required information stored in our environment variables, we can begin the process of creating the Azure Front Door service and its associated dependencies. First, we will create an Azure Private Link service that will allow Azure Front Door to connect to your Azure Red Hat OpenShift cluster. To do so, run the following command:

    ```bash
    az network private-link-service create \
    --name ${AZ_USER}-pls \
    --resource-group ${AZ_RG} \
    --private-ip-address-version IPv4 \
    --private-ip-allocation-method Dynamic \
    --vnet-name ${AZ_USER}-vnet \
    --subnet $(echo ${WORKER_SUBNET_ID} | sed 's/.*\///') \
    --lb-frontend-ip-configs ${LBCONFIG_ID}
    ```

1. Once the Private Link service has been created, let's grab the ID and store it for future use. To do so, run the following command:

    ```bash
    PL_ID=$(az network private-link-service show \
    -n ${AZ_USER}-pls -g ${AZ_RG} --query 'id' -o tsv)
    echo "PrivateLink ID: ${PL_ID}"
    ```

1. Next, let's create an instance of Azure Front Door. To do so, run the following command:

    ```bash
    az afd profile create \
    --resource-group ${AZ_RG} \
    --profile-name ${AZ_USER}-afd-${UNIQUE} \
    --sku Premium_AzureFrontDoor
    ```

1. Once the Front Door instance has been created, let's grab the ID and storage it for future use. To do so, run the following command:

    ```bash
    export AFD_ID=$(az afd profile show -g ${AZ_RG} \
    --profile-name ${AZ_USER}-afd-${UNIQUE} --query 'id' -o tsv)
    echo "Front Door ID: ${AFD_ID}"
    ```

1. Next, we need to create an Azure Front Door endpoint for the ARO internal load balancer. This will allow Azure Front Door to send traffic directly to the ARO Load Balancer. To do so, run the following command:

    ```bash
    az afd endpoint create \
    --resource-group ${AZ_RG} \
    --enabled-state Enabled \
    --endpoint-name ${AZ_USER}-ilb-${UNIQUE} \
    --profile-name ${AZ_USER}-afd-${UNIQUE}
    ```

1. Now we need to create an Azure Front Door origin group that will point to the ARO internal load balancer. An origin group in Azure Front Door refers to a set of origins, which we'll create in just a moment. To do so, run the following command:

    ```bash
    az afd origin-group create \
    --origin-group-name ${AZ_USER}-afd-og \
    --probe-path '/' \
    --probe-protocol HTTP \
    --probe-request-type HEAD \
    --profile-name ${AZ_USER}-afd-${UNIQUE} \
    --resource-group ${AZ_RG} \
    --probe-interval-in-seconds 120 \
    --sample-size 4 \
    --successful-samples-required 3 \
    --additional-latency-in-milliseconds 50
    ```

1. Now that we have an origin group, we'll create an Azure Front Door origin in the origin group that will point to the ARO internal load balancer. To do so, run the following command:

    ```bash
    az afd origin create \
    --enable-private-link true \
    --private-link-resource ${PL_ID} \
    --private-link-location ${AZ_LOCATION} \
    --private-link-request-message 'Private link service from AFD' \
    --weight 1000 \
    --priority 1 \
    --http-port 80 \
    --https-port 443 \
    --origin-group-name ${AZ_USER}-afd-og \
    --enabled-state Enabled \
    --host-name ${LBCONFIG_IP} \
    --origin-name ${AZ_USER}-afd-origin \
    --profile-name ${AZ_USER}-afd-${UNIQUE} \
    --resource-group ${AZ_RG} \
    --origin-host-header app.${AZ_USER}.ws.mobb.cloud
    ```

    Interested in learning more about Azure Front Door origins and origin groups, [click here to read the Azure documentation](https://learn.microsoft.com/en-us/azure/frontdoor/origin?pivots=front-door-standard-premium).

1. Next, we need to approve the Private Link connection between Azure Front Door and your Azure Red Hat OpenShift (ARO). To do so, run the following command:

    ```bash
    az network private-endpoint-connection approve \
    --description 'Approved' \
    --id $(az network private-link-service show \
    -n ${AZ_USER}-pls -g ${AZ_RG} --query \
    'privateEndpointConnections[0].id' -o tsv)
    ```

1. Now, we need to add your custom domain to Azure Front Door. For this workshop, your custom domain will be your username.ws.mobb.cloud (for example, user0 will use user0.ws.mobb.cloud). To do so, run the following command:

    ```bash
    az afd custom-domain create \
    --certificate-type ManagedCertificate \
    --custom-domain-name "app" \
    --host-name "app.${AZ_USER}.ws.mobb.cloud" \
    --minimum-tls-version TLS12 \
    --profile-name ${AZ_USER}-afd-${UNIQUE} \
    --resource-group ${AZ_RG}
    ```

    Do note, this step takes about 5 minutes to propagate to the various global Azure endpoints.

1. Once we've added our custom domain to Azure Front Door, we now need to validate that we control it. To do so, we'll add a validation token to the domain in the form of a TXT record. To do so, run the following command:

    ```bash
    az network dns record-set txt add-record \
    -g ${AZ_RG} \
    -z ${AZ_USER}.ws.mobb.cloud \
    -n _dnsauth.app \
    --value $(az afd custom-domain show -g ${AZ_RG} \
    --profile-name ${AZ_USER}-afd-${UNIQUE} \
    --custom-domain-name "app" \
    --query "validationProperties.validationToken") \
    --record-set-name _dnsauth.app
    ```

1. Now, we can check if the domain has been validated by Azure Front Door by running the following command, but do note it can take several minutes for Azure Front Door to validate your domain. To do so, run the following watch command:

    ```bash
    watch "az afd custom-domain list -g ${AZ_RG} \
    --profile-name ${AZ_USER}-afd-${UNIQUE} \
    --query '[? contains(hostName, \`app.${AZ_USER}.ws.mobb.cloud\`)].domainValidationState'"
    ```

    !!! info

        Watch will refresh the output of a command every two seconds. Hit CTRL and c on your keyboard to exit the watch command when you're ready to move on to the next part of the workshop.

    When the output of watch returns *Approved*, you are safe to proceed to the next step.

1. Next, we need to create a route to connect our endpoint to our origin group. To do so, run the following command:

    ```bash
    az afd route create \
    --endpoint-name ${AZ_USER}-ilb-${UNIQUE} \
    --forwarding-protocol HttpOnly \
    --https-redirect Enabled \
    --origin-group ${AZ_USER}-afd-og \
    --route-name ${AZ_USER}-afd-route \
    --supported-protocols Https \
    --custom-domains app \
    --profile-name ${AZ_USER}-afd-${UNIQUE} \
    --resource-group ${AZ_RG}
    ```

1. Once your domain has been successfully validated and your route has been created, you'll need to create a CNAME record in your custom domain that points to the Azure Front Door endpoint. To do so, run the following command:

    ```bash
    az network dns record-set cname set-record \
      -g ${AZ_RG} \
      -z ${AZ_USER}.ws.mobb.cloud \
      -n "app" \
      -c $(az afd endpoint show -g ${AZ_RG} \
      --profile-name ${AZ_USER}-afd-${UNIQUE} \
      --endpoint-name ${AZ_USER}-ilb-${UNIQUE} \
      --query "hostName" -o tsv)
    ```

Congratulations! You've successfully configured Azure Front Door!
