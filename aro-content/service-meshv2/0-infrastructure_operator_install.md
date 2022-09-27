## Operator Overview
### Red Hat OpenShift Service Mesh requires the following four Operators:

1. **OpenShift Elasticsearch** - (Optional) Provides database storage for tracing and logging with the distributed tracing platform. It is based on the open source Elasticsearch project.

1. **Red Hat OpenShift distributed tracing platform** - Provides distributed tracing to monitor and troubleshoot transactions in complex distributed systems. It is based on the open source Jaeger project.

1. **Kiali** - Provides observability for your service mesh. Allows you to view configurations, monitor traffic, and analyze traces in a single console. It is based on the open source Kiali project.

1. **Red Hat OpenShift Service Mesh** - Allows you to connect, secure, control, and observe the microservices that comprise your applications. The Service Mesh Operator defines and monitors the ServiceMeshControlPlane resources that manage the deployment, updating, and deletion of the Service Mesh components. It is based on the open source Istio project.

### Installing the Operators
#### To install Red Hat OpenShift Service Mesh, install following Operators in this order. Repeat the procedure for each Operator.

1. **OpenShift Elasticsearch**

1. **Red Hat OpenShift distributed tracing platform**

1. **Kiali**

1. **Red Hat OpenShift Service Mesh**

### Procedure
1. Log in to the OpenShift Container Platform web console as a user with the cluster-admin role. If you use Red Hat OpenShift Dedicated, you must have an account with the dedicated-admin role.

1. In the OpenShift Container Platform web console, click **Operators → OperatorHub.**

1. Type the name of the Operator into the filter box and select the Red Hat version of the Operator. Community versions of the Operators are not supported.

1. Click **Install**.

1. On the **Install Operator** page for each Operator, accept the default settings.

1. Click **Install**. Wait until the Operator has installed before repeating the steps for the next Operator in the list.

  * The OpenShift Elasticsearch Operator is installed in the openshift-operators-redhat namespace and is available for all namespaces in the cluster.

  * The Red Hat OpenShift distributed tracing platform is installed in the openshift-distributed-tracing namespace and is available for all namespaces in the cluster.

  * The Kiali and Red Hat OpenShift Service Mesh Operators are installed in the openshift-operators namespace and are available for all namespaces in the cluster.

1. After all you have installed all four Operators, click **Operators → Installed Operators** to verify that your Operators installed.
