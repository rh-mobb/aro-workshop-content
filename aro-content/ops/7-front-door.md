## Configure Azure Front Door

Azure Front Door is Microsoft’s Content Delivery Network (CDN) which provides a fast, reliable, and secure connection between your users and your applications’ content. Azure Front Door delivers your content using the Microsoft’s global edge network with hundreds of global and local POPs distributed around the world. Azure Front Door allows you to privately connect to your Azure Red Hat OpenShift (ARO) cluster using Azure Private Link. This helps to protect your apps from malicious actors and allows you to embrace a zero-trust access model.

To begin, we first need to get the name of the vNet that ARO is in. To do so, run the following command:

```bash
export VNET_NAME=$(az network vnet list \
-g ${AZ_RG} --query '[0].name' -o tsv)
```

To ensure we don't inadvertently collide with another user, we should generate a unique random number to append to our services. To do so, run the following command:

```bash
export UNIQUE=$RANDOM
```

While we have a resource group that contains the Azure Red Hat OpenShift (ARO) cluster object, the ARO service itself creates a separate resource group that is fully controlled by the ARO service. This resource group contains all the virtual machines, storage accounts, load balancers, and more that ARO needs to function. To identify that resource group, run the following command:

```bash
export CLUSTER_RG=$(az aro show -n ${AZ_ARO} \
-g ${AZ_RG} --query 'clusterProfile.resourceGroupId' -o tsv | cut -d/ -f5)
```

Since Azure Front Door connects to your Azure Red Hat OpenShift (ARO) cluster via Azure Private Link, we need to get a few pieces of information so we can configure the Private Link. To do so, run the following commands:

```bash
export WORKER_SUBNET_ID=$(az aro show -n ${AZ_ARO} \
-g ${AZ_RG} --query 'workerProfiles[0].subnetId' -o tsv)
export INTERNAL_LBNAME=$(az network lb list -g ${CLUSTER_RG} \
--query "[? contains(name, 'internal')].name" -o tsv)
export LBCONFIG_ID=$(az network lb frontend-ip list -g ${CLUSTER_RG} \
--lb-name ${INTERNAL_LBNAME} --query \
"[? contains(subnet.id,'${WORKER_SUBNET_ID}')].id" -o tsv)
export LBCONFIG_IP=$(az network lb frontend-ip list -g ${CLUSTER_RG} \
--lb-name ${INTERNAL_LBNAME} --query \
"[? contains(subnet.id,'${WORKER_SUBNET_ID}')].privateIpAddress" \
-o tsv)
```

Now that we have all the required information stored in our environment variables, we can begin the process of creating the Azure Front Door service and its associated dependencies.

First, we will create an Azure Private Link service that will allow Azure Front Door to connect to your Azure Red Hat OpenShift cluster. To do so, run the following command:

```bash
az network private-link-service create \
--name ${USERID}-pls \
--resource-group ${AZ_RG} \
--private-ip-address-version IPv4 \
--private-ip-allocation-method Dynamic \
--vnet-name ${VNET_NAME} \
--subnet $(echo ${WORKER_SUBNET_ID} | sed 's/.*\///') \
--lb-frontend-ip-configs ${LBCONFIG_ID}
```

Once the Private Link service has been created, let's grab the ID and store it for future use. To do so, run the following command:

```bash
PL_ID=$(az network private-link-service show \
-n ${USERID}-pls -g ${AZ_RG} --query 'id' -o tsv)
```

Next, let's create an instance of Azure Front Door. To do so, run the following command:

```bash
az afd profile create \
--resource-group ${AZ_RG} \
--profile-name ${USERID}-afd-${UNIQUE} \
--sku Premium_AzureFrontDoor
```

Once the Front Door instance has been created, let's grab the ID and storage it for future use. To do so, run the following command: 

```bash
export AFD_ID=$(az afd profile show -g ${AZ_RG} \
--profile-name ${USERID}-afd-${UNIQUE} --query 'id' -o tsv)
```

Next, we need to create an Azure Front Door endpoint for the ARO internal load balancer. This will allow Azure Front Door to send traffic directly to the ARO Load Balancer.

```bash
az afd endpoint create \
--resource-group ${AZ_RG} \
--enabled-state Enabled \
--endpoint-name ${USERID}-ilb-${UNIQUE} \
--profile-name ${USERID}-afd-${UNIQUE}
```

Now we need to create an Azure Front Door origin group that will point to the ARO internal load balancer. An origin group in Azure Front Door refers to a set of origins, which we'll create in just a moment. 

```bash
az afd origin-group create \
--origin-group-name ${USERID}-afd-og \
--probe-path '/' \
--probe-protocol Http \
--probe-request-type GET \
--probe-interval-in-seconds 100 \
--profile-name ${USERID}-afd-${UNIQUE} \
--resource-group ${AZ_RG} \
--probe-interval-in-seconds 120 \
--sample-size 4 \
--successful-samples-required 3 \
--additional-latency-in-milliseconds 50
```

Now that we have an origin group, we'll create an Azure Front Door origin in the origin group that will point to the ARO internal load balancer.

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
--origin-group-name ${USERID}-afd-og \
--enabled-state Enabled \
--host-name ${LBCONFIG_IP} \
--origin-name ${USERID}-afd-origin \
--profile-name ${USERID}-afd-${UNIQUE} \
--resource-group $ARORG
```

Interested in learning more about Azure Front Door origins and origin groups, [click here to read the Azure documentation](https://learn.microsoft.com/en-us/azure/frontdoor/origin?pivots=front-door-standard-premium). 

Next, we need to approve the Private Link connection between Azure Front Door and your Azure Red Hat OpenShift (ARO). To do so, run the following command:

```bash
az network private-endpoint-connection approve \
--description 'Approved' \
--id $(az network private-link-service show \
-n ${USERID}-pls -g ${AZ_RG} --query \
'privateEndpointConnections[0].id' -o tsv)
```

Now, we need to add your custom domain to Azure Front Door. For this workshop, your custom domain will be your username.ws.mobb.cloud (for example, user0 will use user0.ws.mobb.cloud). To do so, run the following command:

```bash
az afd custom-domain create \
--certificate-type ManagedCertificate \
--custom-domain-name "${USERID}.ws.mobb.cloud" \
--host-name "app.${USERID}.ws.mobb.cloud" \
--minimum-tls-version TLS12 \
--profile-name ${USERID}-afd-${UNIQUE} \
--resource-group ${AZ_RG}
```

Do note, this step takes about 5 minutes to propagate to the various global Azure endpoints. 

Once we've added our custom domain to Azure Front Door, we now need to validate that we control it. To do so, we'll add a validation token to the domain in the form of a TXT record. To do so, run the following command:

```bash
az network dns record-set txt add-record \
-g ${AZ_RG} \
-z ${USERID}.ws.mobb.cloud \
-n _dnsauth.app \
--value $(az afd custom-domain show -g ${AZ_RG} \
--profile-name ${USERID}-afd-${UNIQUE} --custom-domain-name "app.${USERID}.ws.mobb.cloud" \
--query "validationProperties.validationToken") \
--record-set-name _dnsauth.app
```

Now, we can check if the domain has been validated by Azure Front Door by running the following command, but do note it can take several minutes for Azure Front Door to validate your domain. 

```
az afd custom-domain list -g ${AZ_RG} \
--profile-name ${USERID}-afd-${UNIQUE} --query \
"[? contains(hostName, app.${USERID}.ws.mobb.cloud)].domainValidationState"
```

Once your domain has been successfully validated, you'll need to create a CNAME record in your custom domain that points to the Azure Front Door endpoint. To do so, run the following command:

```bash
az network dns record-set cname set-record \
-g ${AZ_RG} \
-z ${USERID}.ws.mobb.cloud \
-n "app" 
-c $(az afd endpoint show -g ${AZ_RG} \
--profile-name ${USERID}-afd-${UNIQUE} --endpoint-name ${USERID}-ilb-${UNIQUE} \
--query "hostName" -o tsv)
```

Congratulations! You've successfully configured Azure Front Door! 