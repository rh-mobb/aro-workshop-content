#!/usr/bin/env bash

cd ~
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz > openshift-client-linux.tar.gz

mkdir openshift

tar -zxvf openshift-client-linux.tar.gz -C openshift

echo 'export PATH=$PATH:~/openshift' >> ~/.bashrc && source ~/.bashrc

oc completion bash > ~/openshift/oc_bash_completion

echo 'source ~/openshift/oc_bash_completion' >> ~/.bashrc && source ~/.bashrc

az account set --subscription 'my-subscription-name'

curl -Ls https://sh.jbang.dev | bash -s - trust add https://repo1.maven.org/maven2/io/quarkus/quarkus-cli/
curl -Ls https://sh.jbang.dev | bash -s - app install --fresh --force quarkus@quarkusio

curl -L https://github.com/a8m/envsubst/releases/download/v1.2.0/envsubst-`uname -s`-`uname -m` -o envsubst
chmod +x envsubst
mkdir envsub
mv envsubst envsub/
echo 'export PATH=$PATH:~/envsub' >> ~/.bashrc && source ~/.bashrc

wget https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/tkn-linux-amd64.tar.gz
mkdir tkn
tar -xvf tkn-linux-amd64.tar.gz -C tkn 
echo 'export PATH=$PATH:~/tkn' >> ~/.bashrc && source ~/.bashrc