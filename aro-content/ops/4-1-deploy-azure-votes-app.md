## Overview

Applications running on ARO often use other Azure services like databases, caching, message queues or storage. Using ASO, these services can be managed directly inside the cluster. In this task we will deploy an Azure Cache for Redis database that can be used by an application running on OpenShift. Azure Cache for Redis is a fully managed, in-memory cache that enables high-performance and scalable architectures.

To proceed with this task you will need to have completed the **Deploy Azure Service Operator** task from the previous section.

The Azure Voting App that will be deployed consists of a front end web-app that uses an Azure Cache for Redis instance to provide persistence of votes received for Cats and Dogs. The application interface has been built using Python / Flask.

### Create a project to use for the application

OpenShift uses Projects to separate application resources on the cluster. Create a project for the Azure Voting App:

```bash
oc create project azure-voting-app
```

### Deploy an Azure Cache for Redis Instance

The first step to deploying the application is to deploy the Redis cache. The manifest file shown below creates a Basic instance in the US East 1 region:

``` title="redis-cache.yaml"
--8<-- "redis-cache.yaml"
```

To create the cache, run the following command from your Azure Cloud Shell terminal:

```bash
oc apply -f https://rh-mobb.github.io/aro-hackathon-content/assets/redis-cache.yaml
```

Verify that the cache is ready by running:

```bash
oc get TODO
```

```bash
OUTPUT
```

### Deploy the Azure Voting App

The Azure Voting App will be deployed from a pre-built container that is stored in the public Microsoft Azure Container Registry. It's environment variables are configured to use the URL of the Redis cache deployed in the last step, and a Kubernetes Secret that was created as part of the cache deployment.

``` title="vote-app-deployment.yaml"
--8<-- "vote-app-deployment.yaml"
```

To deploy the app, run the following command:

```bash
oc apply -f https://rh-mobb.github.io/aro-hackathon-content/assets/vote-app-deployment.yaml
```

### Expose the Application

OpenShift Routes allow you to host your application at a public URL. This application uses an unsecured route to expose the voting application:

``` title="vote-app-route.yaml"
--8<-- "vote-app-route.yaml"
```

To expose the app, run the following command:

```bash
oc apply -f https://rh-mobb.github.io/aro-hackathon-content/assets/vote-app-route.yaml
```

To verify the application is up and running, retrieve the route and visit the URL in a browser:

```bash
oc get route vote-route
```

```bash
OUTPUT
```











