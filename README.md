# ARO Hack-a-Thon Content

## ARO Workshop

This repository hosts the Cloud Services Black Belt workshop for Azure Red Hat Openshift (ARO) which is hosted at [ws.mobb.cloud](https://ws.mobb.cloud)

### Contribution

Contributions should follow the standard GitHub Pull Request workflow and should follow the MkDocs Markdown formatting. The menu is found in `mkdocs.yml` which determines the Menus and flow of the workshop.

### Hosting your own Workshop

> Note: You need to have python and virtualenv on your system, and be logged into an OpenShift cluster in order to proceed.

1. Clone the repo

    ```bash
    git clone https://github.com/rh-mobb/aro-workshop-content
    cd aro-workshop-content
    ```

1. Run `make preview` to create a local preview of the workshop content

    ```bash
    make preview
    ```

1. Modify the repo to suit your environment

    For example you can remove the `acs` sections in `mkdocs.yml` to remove the ACS content.

1. Update the `extras` section in `mkdocs.yml`

    These values will be injected into the workshop content where appropriate to ensure the workshop matches your environment.

1. Deploy the workshop to an OpenShift cluster

    ```bash
    make deploy
    ```

1. remove the workshop from the OpenShift cluster

    ```bash
    make destroy
    ```
