#!/usr/bin/env bash

mkdir -p ~/bin
mkdir -p ~/scratch
cd ~/scratch

echo "Installing OC cli"

if ! which oc > /dev/null; then
  curl -Ls https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | tar xzf -

  install oc ~/bin
  install kubectl ~/bin
fi

echo "Configure OC bash completion"
# oc completion bash > ~/bin/oc_bash_completion


echo "Installing Quarkus"
if ! which quarkus > /dev/null; then
  curl -Ls https://sh.jbang.dev | bash -s - trust add https://repo1.maven.org/maven2/io/quarkus/quarkus-cli/
  curl -Ls https://sh.jbang.dev | bash -s - app install --fresh --force quarkus@quarkusio
fi

echo "Installing envsubst"
if ! which envsubst > /dev/null; then
  curl -Ls https://github.com/a8m/envsubst/releases/download/v1.2.0/envsubst-`uname -s`-`uname -m` -o envsubst
  install envsubst ~/bin
fi

echo "Installing tekton cli"
if ! which tkn > /dev/null; then
  curl -Ls https://mirror.openshift.com/pub/openshift-v4/clients/pipeline/latest/tkn-linux-amd64.tar.gz | tar xzf -
  install tkn ~/bin
fi

echo "Installing Siege"
if ! which siege > /dev/null; then
  echo "Compiling Siege, this may take a few minutes..."
  curl -Ls http://download.joedog.org/siege/siege-4.1.5.tar.gz | tar xzf -
  cd siege-4.1.5
  ./configure --prefix=${HOME} --with-ssl
  make > /dev/null
  make install > /dev/null
  mkdir -p ~/.siege
  siege.config > /dev/null
fi

echo "Installing various Azure CLI extensions"
az extension add --name "connectedk8s" --yes
az extension add --name "k8s-configuration" --yes
az extension add --name "k8s-extension" --yes

echo "Configuring Environment specific variables"
cat <<"EOF" > ~/.workshoprc
#!/bin/bash
# source ~/bin/oc_bash_completion
export AZ_USER=$(az ad signed-in-user show --query "userPrincipalName" -o tsv | cut -d @ -f1)
export USERID="${AZ_USER}"
export AZ_PASS="R3dH4t1!"

export AZ_RG="${AZ_USER}-rg"
export AZ_ARO="${AZ_USER}-cluster"
export AZ_LOCATION='eastus'

export OCP_PASS=$(az aro list-credentials --name "${AZ_ARO}" --resource-group "${AZ_RG}" \
  --query="kubeadminPassword" -o tsv)
export OCP_USER="kubeadmin"
export OCP_CONSOLE="$(az aro show --name ${AZ_ARO} --resource-group ${AZ_RG} \
  -o tsv --query consoleProfile)"
export OCP_API="$(az aro show --name ${AZ_ARO} --resource-group ${AZ_RG} \
  --query apiserverProfile.url -o tsv)"

alias k=kubectl

export UNIQUE=$RANDOM
EOF

echo "source ~/.workshoprc" >> ~/.bashrc

cd ~
echo "******SETUP COMPLETE *******"
echo
echo
echo "Run '. ~/.workshoprc' to enable bash completion and load environment specific variables"

