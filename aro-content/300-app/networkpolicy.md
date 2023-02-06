# Applying Network Policies to lock down networking

You should have two application deployed in your cluster, the `microsweeper` application deployed in the `Deploy an App` portion of this workshop and the `bgd` app deployed in the `gitops` portion of this workshop. Each live in their own named Projects (or namespace in Kubernetes-speak).

1. Fetch the IP address of the `microsweeper` Pod

    ```bash
    MS_IP=$(oc -n microsweeper-ex get pod -l \
      "app.kubernetes.io/name=microsweeper-appservice" \
      -o jsonpath="{.items[0].status.podIP}")
    echo $MS_IP
    ```

1. Check to see if the `bgd` app can access the Pod.

    ```bash
    oc -n bgd exec -ti deployment/bgd -- curl $MS_IP:8080 | head
    ```

    The output should show a successful connection

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

1. It's common to want to not allow Pods from another Project. This can be done by a fairly simple Network Policy.

    !!! info "This Network Policy will restrict Ingress to the Pods in the project `microsweeper-ex` to just the OpenShift Ingress Pods and only on port 8080."

    ```yaml
    cat << EOF | oc apply -f -
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-from-openshift-ingress
      namespace: microsweeper-ex
    spec:
      ingress:
      - from:
        - namespaceSelector:
            matchLabels:
              network.openshift.io/policy-group: ingress
      podSelector: {}
      policyTypes:
        - Ingress
    EOF
    ```

1. Try to access microsweeper from the bgd pod again

    ```bash
    oc -n bgd exec -ti deployment/bgd -- curl $MS_IP:8080 | head
    ```

    This time it should fail to connect. Hit Ctrl-C to avoid having to wait until a timeout.

    !!! info "If you have your browser still open to the microsweeper app, you can refresh and see that you can still access it."

1. Sometimes you want your application to be accessible to other namespaces. You can allow access to just your microsweeper frontend from the `bgd` pods in the `bgd` namespace like so

    ```yaml
    cat <<EOF | oc apply -f -
    kind: NetworkPolicy
    apiVersion: networking.k8s.io/v1
    metadata:
      name: allow-bgd-ap
      namespace: microsweeper-ex
    spec:
      podSelector:
        matchLabels:
          app.kubernetes.io/name: microsweeper-appservice
      ingress:
        - from:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: bgd
            podSelector:
              matchLabels:
                app: bgd
    EOF
    ```

1. Check to see if the `bgd` app can access the Pod.

    ```bash
    oc -n bgd exec -ti deployment/bgd -- curl $MS_IP:8080 | head
    ```

    The output should show a successful connection

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

1. To verify that only the bgd app can access microsweeper run

    ```bash
    oc -n bgd exec -ti deployment/argocd-server -- curl $MS_IP:8080 | head
    ```

    This should fail.  Hit Ctrl-C to avoid waiting for a timeout.

!!! info "For information on setting default network policies for new projects you can read the OpenShift documentation on [modifying the default project template](https://docs.openshift.com/container-platform/4.10/networking/network_policy/default-network-policy.html)."
