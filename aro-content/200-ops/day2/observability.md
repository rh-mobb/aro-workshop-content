# Configure Metrics and Log Forwarding to Azure Files

OpenShift stores logs and metrics inside the cluster by default, however it also provides tooling to forward both to various locations. Here we will configure ARO
to forward logs and metrics to Azure Files and use Grafana to view them.

<!--
## Configure User Workload Metrics

User Workload Metrics is a Prometheus stack that runs in the cluster that can collect metrics from your applications.

1. Enable user workload metrics

    ```bash
    cat << EOF | oc apply -f -
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cluster-monitoring-config
      namespace: openshift-monitoring
    data:
      config.yaml: |
        enableUserWorkload: true
        alertmanagerMain: {}
        prometheusK8s: {}
    EOF
    ```

1. Watch as the user workload prometheus is created

    ```bash
    oc -n openshift-user-workload-monitoring get pods --watch
    ```

    Once the output looks like this you can run `CTRL-C` and move on.

    ```{.text .no-copy}
    NAME                                  READY   STATUS    RESTARTS   AGE
    prometheus-operator-58768d7cc-hp796   2/2     Running   0          47s
    prometheus-user-workload-0            6/6     Running   0          45s
    prometheus-user-workload-1            6/6     Running   0          45s
    thanos-ruler-user-workload-0          3/3     Running   0          40s
    thanos-ruler-user-workload-1          3/3     Running   0          40s
    ```


## Configure Cluster Log Forwarding to Azure Files
-->

1. Create a Storage Account

    ```bash
    AZR_STORAGE_ACCOUNT_NAME="${AZ_USER}${UNIQUE}"
    az storage account create --name "${AZR_STORAGE_ACCOUNT_NAME}" -g "${AZ_RG}" --location "${AZ_LOCATION}" --sku Standard_LRS
    ```

1. Fetch your storage account key

    ```bash
    AZR_STORAGE_KEY=$(az storage account keys list -g "${AZ_RG}" \
     -n "${AZR_STORAGE_ACCOUNT_NAME}" --query "[0].value" -o tsv)
    ```

1. Create a storage bucket for logs

    ```bash
    az storage container create --name "aro-logs" \
      --account-name "${AZR_STORAGE_ACCOUNT_NAME}" \
      --account-key "${AZR_STORAGE_KEY}"
    ```

1. Create a storage bucket for metrics

    ```bash
    az storage container create --name "aro-metrics" \
      --account-name "${AZR_STORAGE_ACCOUNT_NAME}" \
      --account-key "${AZR_STORAGE_KEY}"
    ```

1. Deploy ElasticSearch CRDs (not used, but needed for a [bug workaround](https://access.redhat.com/solutions/6990588))

    ```bash
    oc create -f https://raw.githubusercontent.com/openshift/elasticsearch-operator/release-5.5/bundle/manifests/logging.openshift.io_elasticsearches.yaml
    ```

1. Set up the MOBB Helm Chart Repository

    ```bash
    helm repo add mobb https://rh-mobb.github.io/helm-charts/
    helm repo update
    ```

1. Create a project to deploy the Helm charts into

    ```bash
    oc new-project custom-logging
    ```

1. Create list of Operators to install

    ```yaml
    cd ~
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

1. Deploy the Grafana, Cluster Logging, and Loki Operator from the file just created above using Helm

    ```bash
    oc create ns openshift-logging
    oc create ns openshift-operators-redhat
    oc create ns resource-locker-operator
    helm upgrade -n custom-logging clf-operators \
      mobb/operatorhub --install \
      --values ~/clf-operators.yaml
    ```

1. Wait for the Operators to be installed

    ```bash
    while ! oc get grafana; do sleep 5; echo -n .; done
    while ! oc get clusterlogging; do sleep 5; echo -n .; done
    while ! oc get lokistack; do sleep 5; echo -n .; done
    while ! oc get resourcelocker; do sleep 5; echo -n .; done
    ```

1. Deploy Helm Chart to deploy Grafana and forward metrics to Azure

    ```bash
    helm upgrade -n "custom-logging" aro-thanos-af \
      --install mobb/aro-thanos-af --version 0.4.1 \
      --set "aro.storageAccount=${AZR_STORAGE_ACCOUNT_NAME}" \
      --set "aro.storageAccountKey=${AZR_STORAGE_KEY}" \
      --set "aro.storageContainer=aro-metrics" \
      --set "enableUserWorkloadMetrics=true"
    ```

1. Deploy Helm Chart to enable Cluster Log forwarding to Azure

    ```bash
    helm upgrade -n custom-logging aro-clf-blob \
      --install mobb/aro-clf-blob --version 0.1.1 \
      --set "azure.storageAccount=${AZR_STORAGE_ACCOUNT_NAME}" \
      --set "azure.storageAccountKey=${AZR_STORAGE_KEY}" \
      --set "azure.storageContainer=aro-logs"
    ```

1. Wait for the Log Collector agent to be started

    ```bash
    oc -n openshift-logging rollout status daemonset collector
    ```

1. Restart Log Collector

    !!! warning "Sometimes the log collector agent starts before the operator has finished configuring Loki, restarting it here will resolve."

    ```bash
    oc -n openshift-logging rollout restart daemonset collector
    ```

## View the Metrics and Logs

Now that the Metrics and Log forwarding is set up we can view them in Grafana.

1. Fetch the Route for Grafana

    ```bash
    oc -n custom-logging get route grafana-route
    ```

1. Browse to the provided route address and login using your OpenShift kubeadmin credentials (username kubeadmin, password echo $OCP_PASS).

1. View an existing dashboard such as **custom-logging -> Node Exporter -> USE Method -> Cluster**.

    !!! info "These dashboards are copies of the dashboards that are available directly on the OpenShift web console under **Observability**"

    ![](../Images/grafana-metrics.png)

1. Click the Explore (compass) Icon in the left hand menu, select “Loki (Application)” in the dropdown and search for `{kubernetes_namespace_name="custom-logging"}`

    ![](../Images/grafana-logs.png)
