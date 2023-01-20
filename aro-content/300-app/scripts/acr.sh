ACR_NAME=kevcolliacr
ACRPWD=$(az acr credential show -n $ACR_NAME --query 'passwords[0].value' -o tsv)

oc create secret docker-registry \
    --docker-server=$ACR_NAME.azurecr.io \
    --docker-username=$ACR_NAME \
    --docker-password=$ACRPWD \
    --docker-email=unused \
    acr-secret -n minesweeper