# Deploy and Expose an Application
In this section of the workshop, we will deploy an application to a private ARO cluster that has no Internet connectivity and then use Azure Front Door to expose the application so it's accessible over the Internet.  


## Prerequisites
* a private ARO cluster
* oc cli
* Azure Database for PostgreSQL
<br>


You will need to use the provided Virtual Machine to build and deploy the application.  This VM has the following required CLIs and development environment already installed:
* az cli
* oc cli
* [maven cli](https://maven.apache.org/install.html)
* [quarkus cli](https://quarkus.io/guides/cli-tooling)
* [OpenJDK Java 11](https://www.azul.com/downloads/?package=jdk) 

## Deploy an application
Now the fun part, let's deploy an application!  
We will be deploying a Java based application called [microsweeper](https://github.com/redhat-mw-demos/microsweeper-quarkus/tree/ARO).  This is an application that runs on OpenShift and uses a PostgreSQL database to store scores.  With ARO being a first class service on Azure, we will create an Azure Database for PostgreSQL service and connect it to our cluster with a private endpoint.

Prerequisites - this part of the workshop assumes you have already created a Azure Database for PostgreSQL database named microsweeper-database that you created and configured in a previous step.

If you haven't and want to run a simple script to create the database for you the script is located [HERE](scripts/database-install-config.sh)



1. Clone the git repository

   ```bash
   git clone -b ARO https://github.com/redhat-mw-demos/microsweeper-quarkus.git
   ```

1. change to the root directory

   ```bash
   cd microsweeper-quarkus
   ```

1. Ensure Java 1.8 is set at your Java version

   ```bash
   mvn --version
   ``` 

   Look for Java version - 1.8XXXX
   if not set to Java 1.8 you will need to set your JAVA_HOME variable to Java 1.8 you have installed.  To find your java versions run:

   ```bash
   java -version
   ```

   then export your JAVA_HOME variable

   ```bash
   export JAVA_HOME=`/usr/libexec/java_home -v 1.8.0_332`
   ```

1. Log into your openshift cluster
   > Before you deploy your application, you will need to be connected to a private network that has access to the cluster.

   ```bash
   kubeadmin_password=$(az aro list-credentials --name $AROCLUSTER --resource-group $ARORG --query kubeadminPassword --output tsv)
   
   apiServer=$(az aro show -g $ARORG -n $AROCLUSTER --query apiserverProfile.url -o tsv)

   oc login $apiServer -u kubeadmin -p $kubeadmin_password
   ```

1. Create a new OpenShift Project

   ```bash
   oc new-project minesweeper
   ```

1. add the openshift extension to quarkus

   ```bash
   quarkus ext add openshift
   ```

1. Edit microsweeper-quarkus/src/main/resources/application.properties

   Make sure your file looks like the one below, changing the IP address on line 3 to the private ip address of your postgres instance.  You should have gotten your PostgreSQL private IP in the previous step when you created the database instance.
 


   Sample microsweeper-quarkus/src/main/resources/application.properties

   ```
   # Database configurations
   %prod.quarkus.datasource.db-kind=postgresql
   %prod.quarkus.datasource.jdbc.url=jdbc:postgresql://<CHANGE TO PRIVATE IP>:5432/score
   %prod.quarkus.datasource.jdbc.driver=org.postgresql.Driver
   %prod.quarkus.datasource.username=quarkus@microsweeper-database
   %prod.quarkus.datasource.password=r3dh4t1!
   %prod.quarkus.hibernate-orm.database.generation=drop-and-create
   %prod.quarkus.hibernate-orm.database.generation=update

   # OpenShift configurations
   %prod.quarkus.kubernetes-client.trust-certs=true
   %prod.quarkus.kubernetes.deploy=true
   %prod.quarkus.kubernetes.deployment-target=openshift
   #%prod.quarkus.kubernetes.deployment-target=knative
   %prod.quarkus.openshift.build-strategy=docker
   #%prod.quarkus.openshift.expose=true

   # Serverless configurations
   #%prod.quarkus.container-image.group=microsweeper-%prod.quarkus
   #%prod.quarkus.container-image.registry=image-registry.openshift-image-registry.svc:5000

   # macOS configurations
   #%prod.quarkus.native.container-build=true
   ```

1. Build and deploy the quarkus application to OpenShift

   ```bash
   quarkus build --no-tests
   ```


## Test the application
Get the url for your application
```bash
oc get routes -o json | jq -r '.items[0].spec.host'
```

Point your broswer to the application!!
<img src="images/minesweeper.png">

## Expose the application with Front Door
Coming soon ...