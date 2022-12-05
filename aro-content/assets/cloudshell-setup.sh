#!/usr/bin/env bash

<<<<<<< HEAD
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
EOF

export UNIQUE=$RANDOM
echo "export UNIQUE=${UNIQUE}" >> ~/.workshoprc

echo "source ~/.workshoprc" >> ~/.bashrc

=======
>>>>>>> a78436f (initial v2)
cd ~
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz > openshift-client-linux.tar.gz

mkdir openshift

tar -zxvf openshift-client-linux.tar.gz -C openshift

echo 'export PATH=$PATH:~/openshift' >> ~/.bashrc && source ~/.bashrc

oc completion bash > ~/openshift/oc_bash_completion

echo 'source ~/openshift/oc_bash_completion' >> ~/.bashrc && source ~/.bashrc

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

wget http://download.joedog.org/siege/siege-latest.tar.gz
mkdir siege
tar -xvf siege-latest.tar.gz -C siege
echo 'export PATH=$PATH:~/siege' >> ~/.bashrc && source ~/.bashrc

az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
az provider register -n Microsoft.Authorization --wait