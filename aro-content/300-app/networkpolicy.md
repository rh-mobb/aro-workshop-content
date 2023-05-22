## Introduction

NetworkPolicy objects are used to control communication between pods within a cluster. They provide a declarative approach to define and enforce network traffic rules, allowing you to specify the desired network behavior. By using NetworkPolicy objects, you can enhance the overall security of your applications by isolating and segmenting different components within the cluster. These policies enable fine-grained control over network access, allowing you to define ingress and egress rules based on criteria such as IP addresses, ports, and pod selectors.

For this module we will be applying a NetworkPolicy to the previously created 'microsweeper-ex' namespace and using the 'microsweeper' app to test these policies. In addition, we will deploy two new applications to test against the 'microsweeper app.

## Applying Network Policies

1. First, let's create a new project for us to build a new application in. To do so, run the following command:

    ```bash
    oc new-project networkpolicy-test
    ```

1. Next, we will create a new application that will allow us to test connectivity to the microsweeper application. To do so, run the following command:

    ```bash
    cat << EOF | oc apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: networkpolicy-pod
      namespace: networkpolicy-test
      labels:
        app: networkpolicy
    spec:
      securityContext:
        allowPrivilegeEscalation: false
      containers:
        - name: networkpolicy-pod
          image: registry.access.redhat.com/ubi9/ubi-minimal
          command: ["sleep", "infinity"]
    EOF
    ```
    
1. Now, let's grab the IP address of the `microsweeper` pod. To do so, run the following command:

    ```bash
    MS_IP=$(oc -n microsweeper-ex get pod -l \
      "app.kubernetes.io/name=microsweeper-appservice" \
      -o jsonpath="{.items[0].status.podIP}")
    echo $MS_IP
    ```

1. Now, let's validate that the `networkpolicy-pod` can access the `microsweeper` pod. By default, ARO does not implement any NetworkPolicy, so we should be able to easily verify that we can access the microsweeper application. To test this, let's run the following command: 

    ```bash
    oc -n networkpolicy-test exec -ti pod/networkpolicy-pod -- curl $MS_IP:8080 | head
    ```

    The output should show a successful connection to the microsweeper application.

    ```{.html .no-copy}
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta http-equiv="X-UA-Compatible" content="ie=edge">
        <title>Microsweeper</title>
        <link rel="stylesheet" href="css/main.css">
        <script
                src="https://code.jquery.com/jquery-3.2.1.min.js"
    ```

1. While ARO doesn't block inter-project pod traffic by default, it is a common use case to not allow pods to cross communicate between projects (namespaces). This can be done by a fairly simple NetworkPolicy.

    ```yaml
    cat << EOF | oc apply -f -
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-from-openshift-ingress
      namespace: microsweeper-ex
    spec:
      podSelector: {}
      policyTypes:
       - Ingress
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  network.openshift.io/policy-group: ingress
          ports:
            - protocol: TCP
              port: 8080
    EOF
    ```

    !!! info "This Network Policy will restrict ingress to the pods in the project `microsweeper-ex` to only allow traffic from the OpneShift IngressController and only on port 8080."

1. Now that we've implemented that NetworkPolicy, let's try to access the `microsweeper` pod from the `networkpolicy-pod` pod again. To do so, run the following command:

    ```bash
    oc -n networkpolicy-test exec -ti pod/networkpolicy-pod -- curl $MS_IP:8080 | head
    ```

    This time it should fail to connect. You can hit Ctrl + C to avoid having to wait until a timeout.

    !!! info "If you still have your browser open to the microsweeper app, you can refresh and see that you can still access it."

1. In other cases, it you may want to allow your application to be accessible to only _certain_ namespaces. In this example, lets allow access to just your `microsweeper` application from only the `networkpolicy-pod` in the `networkpolicy-test` namespace using a label selector. To do so, run the following command:

    ```yaml
    cat <<EOF | oc apply -f -
    kind: NetworkPolicy
    apiVersion: networking.k8s.io/v1
    metadata:
      name: allow-networkpolicy-pod-ap
      namespace: microsweeper-ex
    spec:
      podSelector:
        matchLabels:
          app.kubernetes.io/name: microsweeper-appservice
      ingress:
        - from:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: networkpolicy-test
            podSelector:
              matchLabels:
                app: networkpolicy
    EOF
    ```

1. Now, let's check to see if `networkpolicy-pod` can access the pod. To do so, run the following command:

    ```bash
    oc -n networkpolicy-test exec -ti pod/networkpolicy-pod -- curl $MS_IP:8080 | head
    ```

    The output should show a successful connection:

      ```{.html .no-copy}
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta http-equiv="X-UA-Compatible" content="ie=edge">
          <title>Microsweeper</title>
          <link rel="stylesheet" href="css/main.css">
          <script
                  src="https://code.jquery.com/jquery-3.2.1.min.js"
      ```

1. Now, let's try a different pod (with a different label) in the `networkpolicy-test` namespace. Let's create a new pod called `new-test`. To do so, run the following command:
    
    ```bash
    cat << EOF | oc apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: new-test
      namespace: networkpolicy-test
      labels:
        app: new-test
    spec:
      securityContext:
        allowPrivilegeEscalation: false
      containers:
        - name: new-test
          image: registry.access.redhat.com/ubi9/ubi-minimal
          command: ["sleep", "infinity"]
    EOF
    ```
    
    Now, let's try to curl the `microsweeper` application by running the following command:
    
    ```bash
     oc -n networkpolicy-test exec -ti pod/new-test -- curl $MS_IP:8080 | head
    ```
    
    This time it should fail to connect. You can hit Ctrl + C to avoid having to wait until a timeout.

To learn more about configuring NetworkPolicy objects, visit the [Red Hat documentation on NetworkPolicy](https://docs.openshift.com/container-platform/4.11/networking/network_policy/about-network-policy.html){:target="_blank"}. Interested in creating a set of default NetworkPolicy objects for new projects? Read more at the [Red Hat documentation on modifying the default project template](https://docs.openshift.com/container-platform/4.11/networking/network_policy/default-network-policy.html){:target="_blank"}.

## Summary and Next Steps

Here you learned:

* How to configure NetworkPolicy objects to prevent cross-project traffic
* How to configure NetworkPolicy objects to filter ingress based on labels