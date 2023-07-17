## Introduction

Azure Red Hat OpenShift (ARO) clusters store log data inside the cluster by default. Understanding metrics and logs is critical in successfully running your cluster. Included with ARO is the OpenShift Cluster Logging Operator, which is intended to simplify log management and analysis within an ARO cluster, offering centralized log collection, powerful search capabilities, visualization tools, and integration with other other Azure systems like [Azure Files](https://azure.microsoft.com/en-us/products/storage/files). 

In this section of the workshop, we'll configure ARO to forward logs and metrics to Azure Files and view them using Grafana.

## Configure Metrics and Log Forwarding to Azure Files

1. First, let's create our Azure Files storage account. To do so, run the following command:

    ```bash
    AZR_STORAGE_ACCOUNT_NAME="${AZ_USER}${UNIQUE}"
    az storage account create --name "${AZR_STORAGE_ACCOUNT_NAME}" -g "${AZ_RG}" --location "${AZ_LOCATION}" --sku Standard_LRS
    ```

1. Next, let's grab our storage account key. To do so, run the following command:

    ```bash
    AZR_STORAGE_KEY=$(az storage account keys list -g "${AZ_RG}" \
     -n "${AZR_STORAGE_ACCOUNT_NAME}" --query "[0].value" -o tsv)
    ```

1. Now, let's create a separate storage bucket for logs and metrics. To do so, run the following command: 

    ```bash
    az storage container create --name "aro-logs" \
      --account-name "${AZR_STORAGE_ACCOUNT_NAME}" \
      --account-key "${AZR_STORAGE_KEY}"
    az storage container create --name "aro-metrics" \
      --account-name "${AZR_STORAGE_ACCOUNT_NAME}" \
      --account-key "${AZR_STORAGE_KEY}"
    ```

1. Next, let's add the MOBB Helm Chart repository. To do so, run the following command:

    ```bash
    helm repo add mobb https://rh-mobb.github.io/helm-charts/
    helm repo update
    ```

1. Now, we need to create a project (namespace) to deploy our logging resources to. To create that, run the following command:

    ```bash
    oc new-project custom-logging
    ```

1. Next, we need to install a few operators to run our logging setup. These operators include the Red Hat Cluster Logging Operator, the Loki operator, the Grafana operator, and more. First, we'll create a list of all the operators we'll need to install by running the following command: 

    ```yaml
    cat <<EOF > clf-operators.yaml
    subscriptions:
      - name: grafana-operator
        channel: v4
        installPlanApproval: Automatic
        source: community-operators
        sourceNamespace: openshift-marketplace
      - name: cluster-logging
        channel: stable
        installPlanApproval: Automatic
        source: redhat-operators
        sourceNamespace: openshift-marketplace
        namespace: openshift-logging
      - name: loki-operator
        channel: stable
        installPlanApproval: Automatic
        source: redhat-operators
        sourceNamespace: openshift-marketplace
        namespace: openshift-operators-redhat
      - name: resource-locker-operator
        channel: alpha
        installPlanApproval: Automatic
        source: community-operators
        sourceNamespace: openshift-marketplace
        namespace: resource-locker-operator
    operatorGroups:
      - name: custom-logging
        targetNamespace: ~
      - name: openshift-logging
        namespace: openshift-logging
        targetNamespace: openshift-logging
      - name: openshift-operators-redhat
        namespace: openshift-operators-redhat
        targetNamespace: all
      - name: resource-locker
        namespace: resource-locker-operator
        targetNamespace: all
    EOF
    ```

1. Next, let's deploy the Grafana, Cluster Logging, and Loki operators from the file we just created above. To do so, run the following command:

    ```bash
    oc create ns openshift-logging
    oc create ns openshift-operators-redhat
    oc create ns resource-locker-operator
    helm upgrade -n custom-logging clf-operators \
      mobb/operatorhub --install \
      --values ./clf-operators.yaml
    ```

1. Now, let's wait for the operators to be installed. 

    !!! info "These will loop through each type of resource until the CRDs for the Operators have been deployed. Eventually you'll see the message `No resources found in custom-logging namespace.` and be returned to a prompt."

    ```bash
    while ! oc get grafana; do sleep 5; echo -n .; done
    while ! oc get clusterlogging; do sleep 5; echo -n .; done
    while ! oc get lokistack; do sleep 5; echo -n .; done
    while ! oc get resourcelocker; do sleep 5; echo -n .; done
    ```

1. Now that the operators have been successfully installed, let's use a helm chart to deploy Grafana and forward metrics to Azure Files. To do so, run the following command:

    ```bash
    helm upgrade -n "custom-logging" aro-thanos-af \
      --install mobb/aro-thanos-af --version 0.4.1 \
      --set "aro.storageAccount=${AZR_STORAGE_ACCOUNT_NAME}" \
      --set "aro.storageAccountKey=${AZR_STORAGE_KEY}" \
      --set "aro.storageContainer=aro-metrics" \
      --set "enableUserWorkloadMetrics=true"
    ```

1. Next, let's ensure that we can access Grafana. To do so, we should fetch its route and try browsing to it with your web browser. To grab the route, run the following command:

    ```bash
    oc -n custom-logging get route grafana-route \
      -o jsonpath='{"https://"}{.spec.host}{"\n"}'
    ```

    !!! warning
        If your browser displays an error that says *'Application is not available'* wait a minute and try again. If it persists you've hit a race condition with certificate creation. Run the following command to try to resolve it

        ```bash
        oc patch -n custom-logging service grafana-alert -p '{ "metadata": { "annotations": null }}'
        oc -n custom-logging delete secret aro-thanos-af-grafana-cr-tls
        oc patch -n custom-logging service grafana-service \
          -p '{"metadata":{"annotations":{"retry": "true" }}}'
        sleep 5
        oc -n custom-logging rollout restart deployment grafana-deployment
        ```

1. Next, let's use another helm chart to deploy forward logs to Azure Files. To do so, run the following command:

    ```bash
    helm upgrade -n custom-logging aro-clf-blob \
      --install mobb/aro-clf-blob --version 0.1.1 \
      --set "azure.storageAccount=${AZR_STORAGE_ACCOUNT_NAME}" \
      --set "azure.storageAccountKey=${AZR_STORAGE_KEY}" \
      --set "azure.storageContainer=aro-logs"
    ```

1. Once the Helm Chart deploys its resource, we need to wait for the Log Collector agent to be started. To watch its status, run the following command:

    ```bash
    oc -n openshift-logging rollout status daemonset collector
    ```

1. Occasionally, the log collector agent starts before the operator has finished configuring Loki. To proactively address this, we need to restart the agent. To do so, run the following command:

    ```bash
    oc -n openshift-logging rollout restart daemonset collector
    ```

    !!! warning
        You may see this warning message which can be safely ignored:

        ```
        Warning: spec.template.metadata.annotations[scheduler.alpha.kubernetes.io/critical-pod]: non-functional in v1.16+; use the "priorityClassName" field instead
        ```


## View the Metrics and Logs

Now that the metrics and log forwarding are forwarding to Azure Files, let's view them in Granfa.

1. First, we'll need to fetch the route for Grafana and visit it in our web browser. To get the route, run the following command:

    ```bash
    oc -n custom-logging get route grafana-route \
      -o jsonpath='{"https://"}{.spec.host}{"\n"}'
    ```

1. Once you get to the Grafana interface, you'll be redirected to login using your ARO credentials that you were given by the workshop team. Once you login, proceed with viewing an existing dashboard such as **custom-logging -> Node Exporter -> USE Method -> Cluster**.

    !!! info "These dashboards are copies of the dashboards that are available directly on the OpenShift Web Console under **Observability**"

    ![](../Images/grafana-metrics.png)

1. Click the Explore (compass) Icon in the left hand menu, select “Loki (Application)” in the dropdown and search for `{kubernetes_namespace_name="custom-logging"}`

    ![](../Images/grafana-logs.png)

### Summary and Next Steps

Here you learned how to:

* Configured metrics and log forwarding to Azure Files.
* View the metrics and logs in a Grafana dashboard. 