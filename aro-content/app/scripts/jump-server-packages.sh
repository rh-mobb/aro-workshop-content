#GIT
yum install git

#JQ
sudo yum install jq -y

#oc and kubectl
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.10/openshift-client-linux.tar.gz
tar -xvf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin

#aws cli 
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

#rosa cli
wget https://mirror.openshift.com/pub/openshift-v4/clients/rosa/latest/rosa-linux.tar.gz
tar -xvf rosa-linux.tar.gz
sudo mv rosa /usr/local/bin

#java
sudo yum install java-11-openjdk-devel -y

#maven
wget https://dlcdn.apache.org/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz
tar -xvf apache-maven-3.8.6-bin.tar.gz
sudo ln -s -f  ~/apache-maven-3.8.6/bin/mvn /usr/local/bin/mvn

#quarkus
sudo yum install quarkus -y

quarkus ext add openshift

curl -Ls https://sh.jbang.dev | bash -s - trust add https://repo1.maven.org/maven2/io/quarkus/quarkus-cli/
curl -Ls https://sh.jbang.dev | bash -s - app install --fresh --force quarkus@quarkusio

#Python39 for Azure CLI
wget https://www.python.org/ftp/python/3.9.6/Python-3.9.6.tgz 
tar xzf Python-3.9.6.tgz 
cd Python-3.9.6 
sudo ./configure --with-system-ffi --with-computed-gotos --enable-loadable-sqlite-extensions
sudo make -j ${nproc} 
sudo make altinstall 

# Azure CLI
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm

echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo
sudo dnf install azure-cli