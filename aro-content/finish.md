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

1. byeeeeeeee!
