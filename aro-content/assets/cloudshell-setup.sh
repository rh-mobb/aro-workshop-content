#!/usr/bin/env bash

mkdir -p ~/bin
mkdir -p ~/scratch
cd ~/scratch

echo "Installing various Azure CLI extensions"
az extension add --name "connectedk8s" --yes
az extension add --name "k8s-configuration" --yes
az extension add --name "k8s-extension" --yes

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

echo "Configuring Environment specific variables"
cat <<EOF > ~/.workshoprc
#!/bin/bash
# source ~/bin/oc_bash_completion
export AZ_USER=$(az ad signed-in-user show --query "userPrincipalName" -o tsv | cut -d @ -f1)
export USERID="${AZ_USER}"
# export AZ_PASS="R3dH4t1!"

export AZ_RG="${AZ_USER}-rg"
export AZ_ARO="${AZ_USER}-cluster"
export AZ_LOCATION='{{ azure_region }}'

alias k=kubectl
EOF

export UNIQUE=$RANDOM
echo "export UNIQUE=${UNIQUE}" >> ~/.workshoprc

echo "source ~/.workshoprc" >> ~/.bashrc

cd ~
echo "******SETUP COMPLETE *******"
echo
echo
echo "Run '. ~/.workshoprc' to load environment specific variables"

