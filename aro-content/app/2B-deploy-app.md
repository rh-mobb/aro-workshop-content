# Deploy and Expose an Application

## Expose the application with Front Door
Up to this point, we have deployed the minesweeper app using the publically available Ingress Controller that comes with OpenShift.  Best practices for ARO clusters is to make them private ( both the api server and the ingress controller) and then exposing the application you need with something like Azure Front Door.

In the following section of the workshop, we will go through setting up Azure Front Door and then exposing our minesweeper application with Azure Front Door using a custom domain.

The following diagram shows what we will configure.
![Image](images/aro-frontdoor.png)

There are several advantages of this approach, namely your cluster and all the resources in your Azure account can remain private, providing you an extra layer of security. Azure FrontDoor operates at the edge so we are controlling traffic before it even gets into your Azure account. On top of that, Azure FrontDoor also offers WAF and DDoS protection, certificate management and SSL Offloading just to name a few benefits.

As you can see in the diagram, Azure Front Door sits on the edge of the Microsoft network and is connected to the cluster via a private link service.  With a private cluster, this means all traffic goes through Front Door and is secured at the edge.  Front Door is then connected to your cluster through a private connection over the Microsoft backbone.

Setting up and configuring Azure Front Door for the minesweeper application is typically something the operations team would do.  If you are interested in going through the steps, you can do so [here](../ops/6-front-door.md)  


## Configure the application to use Front Door
Now that front door has been configured and we have a custom domain pointing to our application, we can now configure the application to use Azure Front Door and your custom domain.

The first thing we need to do is delete the route that is connecting directly to our cluster.

```bash
oc delete route microsweeper-appservice
```

Next, we create a new route that points to our application.

Create new route

```bash
cat << EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  labels:
    app.kubernetes.io/name: microsweeper-appservice
    app.kubernetes.io/version: 1.0.0-SNAPSHOT
    app.openshift.io/runtime: quarkus
    type: private
  name: microsweeper-appservice-fd
spec:
  host: $ARO_APP_FQDN
  to:
    kind: Service
    name: microsweeper-appservice
    weight: 100
    targetPort:
      port: 8080
  wildcardPolicy: None
EOF
```
