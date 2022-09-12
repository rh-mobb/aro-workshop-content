#!/usr/bin/env bash

cd ~
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz > openshift-client-linux.tar.gz

mkdir openshift

tar -zxvf openshift-client-linux.tar.gz -C openshift

echo 'export PATH=$PATH:~/openshift' >> ~/.bashrc && source ~/.bashrc

oc completion bash > ~/openshift/oc_bash_completion

echo 'source ~/openshift/oc_bash_completion' >> ~/.bashrc && source ~/.bashrc

az account set --subscription 'my-subscription-name'
