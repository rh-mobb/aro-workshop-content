## Deploy a Virtual Machine using Azure Service Operator
Azure Service Operator(ASO) is an open-source project by Microsoft Azure. ASO gives you the ability to provision and manages Azure resources within the Kubernetes plane by using familiar Kubernetes tooling and primitives. ASO consists of:
1. Custom Resource Definitions (CRDs) for each of the Azure services that a Kubernetes user can provision.
2. A Kubernetes controller that manages the Azure resources represented by the user-specified Custom Resources. The controller attempts to synchronize the desired state in the user-specified Custom Resource with the actual state of that resource in Azure, creating it if it doesn't exist, updating it if it has been changed, or deleting it.

In this step, we use ASO to provision a PostgreSQL DB and connect applications to Azure resources from within Kubernetes

### Prerequisites

* an ARO cluster

* oc cli

* Azure Service Operator(ASO) operator v2
  
 
### Provision a Virtual Machine

to provision a PostgreSQL DB you need to create the following objects in your cluster:
 - ResourceGroup  
 - VirtualNetwork  
 - VirtualNetworksSubnet
 - NetworkInterface
 - PublicIPAddress
 - NetworkSecurityGroup
 - VirtualMachine

1. **ResourceGroup**  **(if you don't. have Resource Group)**
```
cat <<EOF | oc apply -f -
apiVersion: resources.azure.com/v1beta20200601
kind: ResourceGroup
metadata:
  name: wksp-rg
  namespace: default
spec:
  location: eastus
EOF
```
2. **Provision VM**

   create a virtual network
```
cat <<EOF | oc apply -f -
apiVersion: network.azure.com/v1beta20201101
kind: VirtualNetwork
metadata:
  name: wksp-vnet
  namespace: default
spec:
  location: eastus
  owner:
    name: wksp-rg
  addressSpace:
    addressPrefixes:
      - 10.0.0.0/16
EOF
```
      
   create subnet
      
 ```
cat <<EOF | oc apply -f -
apiVersion: network.azure.com/v1beta20201101
kind: VirtualNetworksSubnet
metadata:
  name: wksp-subnet
  namespace: default
spec:
  location: eastus
  owner:
    name: wksp-vnet
  addressPrefix: 10.0.0.0/24
  networkSecurityGroup: 
      reference: 
         group: network.azure.com
         kind: NetworkSecurityGroup
         name: wksp-nsg
EOF
 ```

create network interface
```
cat  <<EOF | oc apply -f -
apiVersion: network.azure.com/v1beta20201101
kind: NetworkInterface
metadata:
  name: wksp-vm-nic
  namespace: default
spec:
  location: eastus
  owner:
    name: wksp-rg
  ipConfigurations:
    - name: ipconfig1
      privateIPAllocationMethod: Dynamic
      subnet:
        reference:
          group: network.azure.com
          kind: VirtualNetworksSubnet
          name: wksp-subnet
      publicIPAddress:
        reference:
          group: network.azure.com
          kind: PublicIPAddress
          name: wksp-pub-ip

EOF
```
create a public IP address
```
cat  <<EOF | oc apply -f -
apiVersion: network.azure.com/v1beta20201101
kind: PublicIPAddress
metadata:
  name: wksp-pub-ip
  namespace: default
spec:
  location: eastus
  owner:
    name: wksp-rg
  sku:
    name: Standard
  publicIPAllocationMethod: Static
EOF
```

Create Network Security Group(NSG)
```
cat  <<EOF | oc apply -f -
apiVersion: network.azure.com/v1beta20201101
kind: NetworkSecurityGroup
metadata:
  name: wksp-nsg
  namespace: default
spec:
  location: eastus
  owner:
    name: wksp-rg
EOF
```
Create NSG rule

```
cat  <<EOF | oc apply -f -
apiVersion: network.azure.com/v1beta20201101
kind: NetworkSecurityGroupsSecurityRule
metadata:
  name: wksp-nsg-rule
  namespace: default
spec:
  location: eastus
  owner:
    name: wksp-nsg
  protocol: Tcp
  sourcePortRange: "*"
  destinationPortRange: 22-22
  sourceAddressPrefix: "*"
  destinationAddressPrefix: "*"
  access: Allow
  priority: 123
  direction: Inbound
  description: Allow access to source port 23-45 and destination port 45-56
EOF
```
create virtual machine
```
cat  <<EOF | oc apply -f -
apiVersion: compute.azure.com/v1beta20201201
kind: VirtualMachine
metadata:
  name: wksp-vm
  namespace: default
spec:
  location: eastus
  owner:
    name: wksp-rg
  hardwareProfile:
    vmSize: "Standard_A1_v2"
  storageProfile:
    imageReference:
      publisher: Canonical
      offer: UbuntuServer
      sku: 18.04-lts
      version: latest
  osProfile:
    computerName: mhs-aso-vm-hackaton
    adminUsername: adminUser
    linuxConfiguration:
      disablePasswordAuthentication: true
      ssh:
        publicKeys:
          - keyData: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCy/7NBa68TkyJ71K5WLwsxIfTKlfvIo0r2dEBK4Cd3Zwxb+WoN5b+cW2k0xH5J1XCFC3gxwtMgjtIADagolncLVLGkegm3TTEXntPwYXNv3SPGbwrkQo5nkVsjC7RTHPbd67SS1rkF8OQDTkh/QmPrS14X4KBUrbPTbtN2VehKevzhgN0QESphz1BB6uucknNc5gNKcJ4itOiaUfJgfpctQucS4bjL8+eS1ayf5O8d6PRezkfjU0d/+ScCUi7PJKniLKYpYCwTu1EPMlBaTdj+eSvW/EEn0Ptr9+9KKHuJ2zYVb0eI4qS97AH2aQWcIB25Ax0mtoOpi2nWZ4zdvscgpI57Xs+U04R4L65tZu+NEaGOKf2naWG5OXYBEcQeOc7qnbmzxbIjxcAuqwtxrjqAdllwiKxKfdsq49dPgh+mFlDCSKygO6NQXjSlL5HDp/rLt8FCwJVdVlWyfvkMWIxNpRFigFPnbsipNIOcDpW3+qmb7nYzb6+jTX8RnXnuybU= mhs@msarvest-mac  # Specify your SSH public key here
            path: /home/adminUser/.ssh/authorized_keys
  networkProfile:
    networkInterfaces:
      - reference:
          group: network.azure.com
          kind: NetworkInterface
          name: wksp-vm-nic
EOF
```




 
