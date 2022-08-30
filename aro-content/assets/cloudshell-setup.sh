#!/usr/bin/env bash

az account set --subscription 'my-subscription-name'

cd ~
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz > openshift-client-linux.tar.gz

mkdir openshift
tar -zxvf openshift-client-linux.tar.gz -C openshift
mv openshift/oc /usr/local/bin/oc
chmod +x /usr/local/bin/oc
