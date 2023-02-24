## Introduction

Labels are a useful way to select which nodes that an application will run on. These nodes are created by machines which are defined by the MachineSets we worked with in previous sections of this workshop. An example of this would be running a memory intensive application only on a specific node type.

While you can directly add a label to a node, it is not recommended because nodes can be recreated, which would cause the label to disappear. Therefore we need to label the MachineSet itself. An important caveat to this process is that only **new machines** created by the MachineSet will get the label. This means you will need to either scale the MachineSet down to zero then back up to create new machines with the label, or you can label the existing machines directly.

## Set a label for the MachineSet

1. Just like the last section, let's pick a MachineSet to add our label. To do so, run the following command:

    ```bash
    MACHINESET=$(oc -n openshift-machine-api get machinesets -o name | head -1)
    echo ${MACHINESET}
    ```

1. Now, let's review the current definition of the MachineSet. To do so, run the following command (Remember to exit from the editor with :q! ):

    ```bash
    oc -n openshift-machine-api edit $MACHINESET
    ```

1. Now, let's patch the MachineSet with our new label. To do so, run the following command:
    ```bash
    oc -n openshift-machine-api patch ${MACHINESET} \
      --type=merge -p '{"spec":{"template":{"spec":{"metadata":
      {"labels":{"tier":"frontend"}}}}}}'
    ```

1. As you'll remember, the existing machines won't get this label, but all new machines will. While we could just scale this MachineSet down to zero and back up again, that could disrupt our workloads. Instead, let's just loop through and add the label to all of our nodes in that MachineSet. To do so, run the following command:

    ```bash
    MACHINES=$(oc -n openshift-machine-api get machines -o name -l "machine.openshift.io/cluster-api-machineset=$(echo $MACHINESET | cut -d / -f2 )" | xargs)
    oc label -n openshift-machine-api ${MACHINES} tier=frontend
    NODES=$(echo $MACHINES | sed 's/machine.machine.openshift.io/node/g')
    oc label ${NODES} tier=frontend
    ```

    !!! info

        Just like MachineSets, machines do not automatically label their existing child resources, this means we need to relabel them ourselves to avoid having to recreate them.

1. Now, let's verify the nodes are properly labeled. To do so, run the following command:

    ```bash
    oc get nodes --selector='tier=frontend' -o name
    ```

    Your output will look something like this:

    ```{.text .no-copy}
    node/user1-mobbws-cluster-zljxp-worker-{{ azure_region }}1-gkhgf
    ```

    Pending that your output shows one or more node(s), this demonstrates that our MachineSet and associated nodes are properly annotated!

## Deploy an app to the labeled nodes

Now that we've successfully labeled our nodes, let's deploy a workload to demonstrate app placement using `nodeSelector`. This should force our app to only our labeled nodes.

1. First, let's create a namespace (also known as a project in OpenShift). To do so, run the following command:

    ```bash
    oc new-project nodeselector-ex
    ```

1. Next, let's deploy our application and associated resources that will target our labeled nodes. To do so, run the following command:

    ```yaml
    cat << EOF | oc create -f -
    kind: Deployment
    apiVersion: apps/v1
    metadata:
      name: nodeselector-app
      namespace: nodeselector-ex
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nodeselector-app
      template:
        metadata:
          labels:
            app: nodeselector-app
        spec:
          nodeSelector:
            tier: frontend
          containers:
            - name: hello-openshift
              image: "docker.io/openshift/hello-openshift"
              ports:
                - containerPort: 8080
                  protocol: TCP
                - containerPort: 8888
                  protocol: TCP
    EOF
    ```

1. Now, let's validate that the application has been deployed to one of the labeled nodes. To do so, run the following command:

    ```bash
    oc -n nodeselector-ex get pod -l app=nodeselector-app -o json \
      | jq -r .items[0].spec.nodeName
    ```

    Your output will look something like this:

    ```{.text .no-copy}
    user1-mobbws-cluster-zljxp-worker-{{ azure_region }}1-gkhgf
    ```

1. Double check the name of the node to compare it to the output above to ensure the node selector worked to put the pod on the correct node

    ```bash
    oc get nodes --selector='tier=frontend' -o name
    ```

    Your output will look something like this (look for the final string to match, in this example `gkhgf`)

    ```{.text .no-copy}
    node/user1-mobbws-cluster-zljxp-worker-{{ azure_region }}1-gkhgf
    ```


1. Next create a `service` using the `oc expose` command

    ```bash
    oc expose deployment nodeselector-app
    ```

1. Expose the newly created `service` with a `route`

    ```bash
    oc create route edge --service=nodeselector-app
    ```

1.  Fetch the URL for the newly created `route`

    ```bash
    oc get routes/nodeselector-app -o json | jq -r '.spec.host'
    ```

    Then visit the URL presented in a new tab in your web browser (using HTTPS). For example, your output will look something similar to:

    ```{.text .no-copy}
    nodeselector-app-nodeselector-ex.apps.ce7l3kf6.{{ azure_region }}.aroapp.io
    ```

1. In the above case, you'd visit `https://nodeselector-app-nodeselector-ex.apps.ce7l3kf6.{{ azure_region }}.aroapp.io` in your browser.

    > Note the application is exposed over the default ingress using a predetermined URL and trusted TLS certificate. This is done using the OpenShift `Route` resource which is an extension to the Kubernetes `Ingress` resource.

Congratulations! You've successfully demonstrated the ability to label nodes and target those nodes using `nodeSelector`.
