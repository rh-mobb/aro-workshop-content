# Deploy and Expose an Application ( Part 1 )

It's time for us to put our cluster to work and install a workload. We're going to build an example Java application, [microsweeper](https://github.com/redhat-mw-demos/microsweeper-quarkus/tree/ARO) deploy it to your ARO cluster and securely expose this application over the internet using Azure Frontdoor.

The microsweeper application depends on a PostgreSQL database to store scores. Since ARO is a first class citizen in Azure, we'll use an Azure Database for PostgreSQL and connect it to our cluster with a private endpoint.

!!! info
    For simplicity sake, we'll be using public clusters for this workshop. The Frontdoor ingress pattern works for public and private clusters.


## Prerequisites
* Your unique USERID
* Azure Database for PostgreSQL
* Azure Container Registry Instance and Password
* A public GitHub id ( only required for the 'Automate Deploying the App' )


## Create PostgreSQL

# Provision DB for Minesweeper APP

To provision a PostgreSQL DB you need to create the following ASO objects in your cluster:

 - ResourceGroup
 - FlexibleServer
 - FlexibleServersDatabase
 - FlexibleServersFirewallRule

Create a project to deploy the application in

```bash
oc new-project minesweeper
```

Create a ResourceGroup to inherit your Azure Resource Group

```bash
cat <<EOF | oc apply -f -
apiVersion: resources.azure.com/v1beta20200601
kind: ResourceGroup
metadata:
  name: ${AZ_RG}
spec:
  location: ${AZ_LOCATION}
EOF
```

Create a secret for the Database

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: server-admin-pw
stringData:
  password: "${AZ_PASS}"
type: Opaque
EOF
```

Create the Azure Postgres Flexible Server

```bash
cat <<EOF | oc apply -f -
apiVersion: dbforpostgresql.azure.com/v1beta20210601
kind: FlexibleServer
metadata:
  name: "${AZ_USER}-minesweeper-database"
spec:
  location: "${AZ_LOCATION}"
  owner:
    name: "${AZ_RG}"
  version: "13"
  sku:
    name: Standard_B1ms
    tier: Burstable
  administratorLogin: myAdmin
  administratorLoginPassword:
    name: server-admin-pw
    key: password
  storage:
    storageSizeGB: 32
EOF
```

Create Server configuration

```bash
cat  <<EOF | oc apply -f -
apiVersion: dbforpostgresql.azure.com/v1beta20210601
kind: FlexibleServersConfiguration
metadata:
  name: pgaudit
spec:
  owner:
    name: "${AZ_USER}-minesweeper-database"
  azureName: pgaudit.log
  source: user-override
  value: READ
EOF
```

Create a firewall rule for the database

```bash
cat  <<EOF | oc apply -f -
apiVersion: dbforpostgresql.azure.com/v1beta20210601
kind: FlexibleServersFirewallRule
metadata:
  name: wksp-fw-rule
spec:
  owner:
    name: "${AZ_USER}-minesweeper-database"
  startIpAddress: 0.0.0.0
  endIpAddress: 255.255.255.255
EOF
```

1. **Create a sample DB**
```bash
cat  <<EOF | oc apply -f -
apiVersion: dbforpostgresql.azure.com/v1beta20210601
kind: FlexibleServersDatabase
metadata:
  name: score
spec:
  owner:
    name: "${AZ_USER}-minesweeper-database"
  charset: utf8
EOF
```

!!! warning
    It takes about 10 minutes for the database to be operational and running

Wait until the database is ready

```bash
watch ~/bin/oc get flexibleservers.dbforpostgresql.azure.com \
  ${AZ_USER}-minesweeper-database
```

Eventually it will show as Succeeded

```{.text .no-copy}
NAME                         READY   SEVERITY   REASON      MESSAGE
user3-minesweeper-database   True               Succeeded
```

check server in Azure portal

![Azure PostgreSQL flexible server](../assets/images/azure-flexible-server.png)

Check connection to DB server

```bash
psql \
  "host=${AZ_USER}-minesweeper-database.postgres.database.azure.com port=5432 dbname=score user=myAdmin password=${AZ_PASS} sslmode=require" \
  -c "select now();"
```

## Deploy Application

From the Azure Cloud Shell, set an environment variable for your user id and the Azure Resource Group given to you by the facilitator:

```bash
export ARO_APP_FQDN=minesweeper.$USERID.azure.mobb.ninja
```

Clone the application from github.

```bash
git clone https://github.com/rh-mobb/aro-hackaton-app
```

Change to the application root directory

```bash
cd aro-hackaton-app
```

Add the OpenShift extension to quarkus

```bash
quarkus ext add openshift
```

Configure Quarkus to use the postgres database you created earlier

```bash
cat <<EOF > ./src/main/resources/application.properties
# Database configurations
%prod.quarkus.datasource.db-kind=postgresql
%prod.quarkus.datasource.jdbc.url=jdbc:postgresql://${AZ_USER}-minesweeper-database.postgres.database.azure.com:5432/score
%prod.quarkus.datasource.jdbc.driver=org.postgresql.Driver
%prod.quarkus.datasource.username=myAdmin
%prod.quarkus.datasource.password=${AZ_PASS}
%prod.quarkus.hibernate-orm.database.generation=drop-and-create
%prod.quarkus.hibernate-orm.database.generation=update

# OpenShift configurations
%prod.quarkus.kubernetes-client.trust-certs=true
%prod.quarkus.kubernetes.deploy=true
%prod.quarkus.kubernetes.deployment-target=openshift
%prod.quarkus.openshift.build-strategy=docker
%prod.quarkus.openshift.expose=true
%prod.quarkus.openshift.deployment-kind=Deployment
%prod.quarkus.container-image.group=minesweeper
EOF
```

For our minesweeper application we will be using source to image and build configs that come built in with Quarkus and OpenShift.  To start the build ( and deploy ) process simply run the following command.

```bash
quarkus build --no-tests
```

Let's take a look at what this did along with everything that was created in your cluster.

### Container Images
Log into the OpenShift Console and from the Administrator perspective, expand Builds and then Image Streams, and select the minesweeper Project.

![Image](images/image-stream-list.png)

You will see two images that were created on your behalf when you ran the quarkus build command.  There is one image for openjdk-11 that comes with OpenShift as a Universal Base Image (UBI) that the application will run under. With UBI, you get highly optimized and secure container images that you can build your applications with.   For more information on UBI please read this [article](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image)

The second image you see is the the microsweeper-appservice image.  This is the image for the application that was built automatically for you and pushed to the container registry that comes with OpenShift.

### Image Build
How did those images get built you ask?   Back on the OpenShift Console, click on Build Configs and then the microsweeper-appservice entry.
![Image](images/build-config-list.png)

When you ran the quarkus build command, this created the BuildConfig you can see here.  In our quarkus settings, we set the deployment strategy to build the image using Docker.  The Dockerfile file from the git repo that we cloned was used for this Build Config.

!!! info
  A build configuration describes a single build definition and a set of triggers for when a new build is created. Build configurations are defined by a BuildConfig, which is a REST object that can be used in a POST to the API server to create a new instance.

You can read more about BuildConfigs [here](https://docs.openshift.com/container-platform/4.11/cicd/builds/understanding-buildconfigs.html)

Once the BuildConfig was created, the source to image process kicked off a Build of that BuildConfig.  The build is what actually does the work in building and deploying the image.  We started with defining what to be built with the BuildConfig and then actually did the work with the Build.
You can read more about Builds [here](https://docs.openshift.com/container-platform/4.11/cicd/builds/understanding-image-builds.html)

To look at what the build actually did, click on Builds tab and then into the first Build in the list.
![Image](images/build-list.png)

On the next screen, explore around and look at the YAML definition of the build, Logs to see what the build actually did.  If you build failed for some reason, logs is a great first place to start to look at to debug what happened.
![Image](images/build-logs.png)

### Image Deployment
After the image was built, the S2I process then deployed the application for us.  In the quarkus properties file, we specified that a deployment should be created.  You can view the deployment under Workloads, Deployments, and then click on the Deployment name.
![Image](images/deployment-list.png)

Explore around the deployment screen, check out the different tabs, look at the YAML that was created.
![Image](images/deployment-view.png)

Look at the pod the deployment created, and see that it is running.
![Image](images/deployment-pod.png)

The last thing we will look at is the Route that was created for our application.  In the quarkus properties file, we specified that the application should be exposed to the Internet.  When you create a Route, you have the option to specify a hostname.  To start with, we will just use the default domain that comes with ARO useast.aroapp.io in our case.  In next section, we will expose the same appplication to a custom domain leveraging Azure Front Door.

You can read more about Routes [here](https://docs.openshift.com/container-platform/4.11/networking/routes/route-configuration.html)

From the OpenShift menu, click on Networking, Routes, and the microsweeper-appservice route.
![Image](images/route-list.png)


## Test the application
While in the Route section of the OpenShift UI, click the url under location:
![Image](images/route.png)

You can also get the the url for your application using the command line:
```bash
oc get routes -o json | jq -r '.items[0].spec.host'
```

Point your browser to the application!!
![Image](images/minesweeper.png)

### Application IP
Let's take a quick look at what IP the application resolves to.  Back in your Cloud Shell environment, run
```bash
nslookup <route host name>

i.e. nslookup microsweeper-appservice-minesweeper.apps.fiehcjr1.eastus.aroapp.io
```

You should see results like the following:
![Image](images/nslookup.png)

Notice the IP address - can you guess where it comes from?

It comes from the ARO Load Balancer.  In this workshop, we are using a Public Cluster which means the load balancer is exposed to the Internet.  If this was a private cluster, you would have to have connectivity to the VNET ARO is running on whether that be VPN, Express Route, or something else.

To view the ARO load balancer, on the Azure Portal, Search for 'Load Balancers' and click on the Load balancers service.
![Image](images/load-balancers-search.png)

Scroll down the list of load balancers until you see the one with your cluster name.  You will notice two load balancers, one that has -internal in the name and one that does not.  The '*-internal' load balancer is used for the OpenShift API.  The other load balancer ( without -internal ) in the name is use the public load balancer used for the default Ingress Controller.  Click into the load balancer for applications.
![Image](images/load-balancers-list.png)

On the next screen, click on Frontend IP configuration.  Notice the IP address of the 2nd load balancer on the list.  This IP address matches what you found with the nslookup command.
![Image](images/load-balancers.png)

For the fun of it, we can also look at what backends this load balancer is connected to. Click into the 2nd load balancer on the list above, and then click into the first rule.
![Image](images/load-balancers-usedby.png)

On the next screen, notice the Backend pool.  This is the subnet that contains all the workers.  And the best part is all of this came with OpenShift and ARO!
![Image](images/load-balancers-backendpool.png)


Continue to [Part 2](2B-deploy-app.md) of Deploy and Expose an App to expose the same application using a custom domain leveraging Azure Front Door.
