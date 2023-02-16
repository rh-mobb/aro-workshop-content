## Access the OpenShift Console and CLI

### Login to the OpenShift Web Console

1. First, let's configure your workshop environment with our helper variables. To do so, let's run the following command:

    ```bash
    cat << EOF >> ~/.workshoprc
    export OCP_PASS=$(az aro list-credentials --name \
      "${AZ_ARO}" --resource-group "${AZ_RG}" \
      --query="kubeadminPassword" -o tsv)
    export OCP_USER="kubeadmin"
    export OCP_CONSOLE="$(az aro show --name ${AZ_ARO} \
      --resource-group ${AZ_RG} \
      -o tsv --query consoleProfile)"
    export OCP_API="$(az aro show --name ${AZ_ARO} \
      --resource-group ${AZ_RG} \
      --query apiserverProfile.url -o tsv)"
    EOF
    source ~/.bashrc
    source ~/.workshoprc
    env | grep -E 'AZ_|OCP'
    ```

    You should see a list of variables including `AZ_USER` and `OCP_CONSOLE`.

    !!! info "Helper Variables"

        We use helper variables extensively throughout this workshop, but we also include the commands we used to populate these helper variables to ensure you can craft these commands later. 

1. To access the OpenShift CLI tools (`oc`) and web console you will need to retrieve your cluster credentials. The helper variables from above will make this simple!

    To retrieve the credentials, run the following command:

    ```bash
    az aro list-credentials --name "${AZ_ARO}" --resource-group "${AZ_RG}"
    ```

1. Next retrieve the console URL by running the following command:

    ```bash
    az aro show --name "${AZ_ARO}" --resource-group \
    "${AZ_RG}" -o tsv --query consoleProfile
    ```

1. Finally, open the link to the console provided in a separate tab, and login with the provided credentials. 

### Login to the OpenShift CLI

Now that you're logged into the cluster's console, return to your Azure Cloud Shell. 

1. To login to the cluster using the OpenShift CLI tools (`oc`), first we need to retrieve the API server endpoint. To do so, run the following command:

    ```bash
    az aro show -g "${AZ_RG}" -n "${AZ_ARO}" --query apiserverProfile.url -o tsv
    ```

1. Now that we've captured the API server endpoint, we can login to the cluster by running the following command:

    ```bash
    oc login "${OCP_API}" -u "${OCP_USER}" -p "${OCP_PASS}"
    ```

    Once logged in, you'll see output that looks like this:

    ```bash
    Login successful.

    You have access to 68 projects, the list has been suppressed. You can list all projects with 'oc projects'

    Using project "default".
    ```

    Congratulations, you're now logged into the cluster and ready to move on to the workshop content.