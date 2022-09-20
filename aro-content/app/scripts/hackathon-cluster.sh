#!/bin/bash
set -ex

az group create --name arohack --location eastus
az network vnet create --address-prefixes 10.1.0.0/16 --name "arohack-vnet" --resource-group arohack
az network vnet subnet create --resource-group arohack --vnet-name arohack-vnet --name arohack-control-subnet --address-prefixes 10.1.0.0/23 --disable-private-endpoint-network-policies true --service-endpoints Microsoft.ContainerRegistry
az network vnet subnet create --resource-group arohack --vnet-name arohack-vnet --name arohack-machine-subnet --address-prefixes 10.1.2.0/23 --disable-private-endpoint-network-policies true --service-endpoints Microsoft.ContainerRegistry
az aro create --resource-group arohack --name arohack --vnet arohack-vnet --master-subnet arohack-control-subnet --worker-subnet arohack-machine-subnet --apiserver-visibility Public --ingress-visibility Public --pull-secret @/Users/kevincollins/Downloads/pull-secret.txt
