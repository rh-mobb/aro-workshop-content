# Thanks for attending the class!

1. Delete your namespaces

    ```bash
    oc delete ns bgd microsweeper-ex resilience-ex
    ```

1. Delete the microsweeper Postgres Database

    ```bash
    az postgres server delete --resource-group "${AZ_RG}" \
      --name "microsweeper-${UNIQUE}" --yes
    ```

1. To delete your cluster when you're done with it run the following command

    ```bash
    az aro delete \
      --resource-group "${AZ_RG}" \
      --name "${AZ_ARO}" --yes
    ```

{% if not redhat_led %}
1. To delete your resource group and any extra left over resources run

    ```bash
    az group delete --yes \
      --resource-group "${AZ_RG}"
    ```

{% endif %}

1. Delete the Azure App you created for IDP

    ```bash
    APPID=$(az ad app list --display-name ${AZ_USER}-idp \
      --query "[].appId" -o tsv)
    az ad app delete --id "${APPID}"
    ```

1. byeeeeeeee!
