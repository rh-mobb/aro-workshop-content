# Deploying your Application with OpenShift GitOps

1. From the OpenShift Console Administrator view click through **HOME** -> **Operators** -> **Operator Hub**, search for "Red Hat OpenShift GitOps" and hit Install.  Accept all defaults.

![](./images/gitops_operator.png)

1. Create a new project

    ```bash
    oc new-project bgd
    ```

1. Deploy ArgoCD into your project

    ```bash
    cat <<EOF | oc apply -f -
    apiVersion: argoproj.io/v1alpha1
    kind: ArgoCD
    metadata:
      name: argocd
    spec:
      dex:
        openShiftOAuth: true
      rbac:
        defaultPolicy: "role:readonly"
        policy: "g, system:authenticated, role:admin"
        scopes: "[groups]"
      server:
        insecure: true
        route:
          enabled: true
          tls:
            insecureEdgeTerminationPolicy: Redirect
            termination: edge
    EOF
    ```


1. Wait for ArgoCD to be ready

    ```bash
    kubectl rollout status deploy/argocd-server
    ```

1. Apply the gitops configuration

    ```bash
    cat <<EOF | oc apply -f -
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: bgd-app
      namespace: bgd
    spec:
      destination:
        namespace: bgd
        server: https://kubernetes.default.svc
      project: default
      source:
        path: apps/bgd/base
        repoURL: https://github.com/rh-mobb/gitops-bgd-app
        targetRevision: main
      syncPolicy:
        automated:
          prune: true
          selfHeal: false
        syncOptions:
        - CreateNamespace=false
    EOF
    ```

1. Find the URL for your Argo CD dashboard and log in using your OpenShift credentials

    ```bash
    oc get route argocd-server -n bgd -o jsonpath='{.spec.host}{"\n"}'
    ```

    ![](./images/argo_app1.png)

1. Click on the Application to show its topology

    ![](./images/argo_sync.png)

1. Verify that OpenShift sees the Deployment as rolled out

    ```bash
    oc rollout status deploy/bgd
    ```

1. Get the route and browse to it in your browser

    ```bash
    oc get route bgd -n bgd -o jsonpath='{.spec.host}{"\n"}'
    ```

1. You should see a green box in the website like so

    ![](./images/bgd_green.png)


1. Patch the OpenShift resource to force it to be out of sync with git

    ```bash
    oc patch deploy/bgd --type='json' \
      -p='[{"op": "replace", "path":
      "/spec/template/spec/containers/0/env/0/value", "value":"blue"}]'
    ```

1. Refresh Your browser and you should see a blue box in the website like so

    ![](./images/app_blue.png)

1. Meanwhile check ArgoCD it should show the application as out of sync. Click the Sync button to have it revert the change you made in OpenShift

    ![](./images/sync_bgd.png)

1. Check again, you should see a green box in the website like so

    ![](./images/bgd_green.png)

1. Patch the ArgoCD application to automatically self Heal

    ```bash
    kubectl patch application bgd-app --type merge \
      -p='{"spec":{"syncPolicy":{"automated":{"selfHeal": true}}}}'
    ```

1. Change the Application again and watch the ArgoCD web gui, you should see the change made in the cluster get quickly reverted back to match what is in git.

    !!! info "The self healing may happen so fast you don't even see it happen."

    ```bash
    oc patch deploy/bgd --type='json' \
      -p='[{"op": "replace", "path":
      "/spec/template/spec/containers/0/env/0/value", "value":"blue"}]'
    ```
