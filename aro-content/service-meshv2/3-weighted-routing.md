## Configuring virtual services

Requests are routed to services within a service mesh with virtual services. Each virtual service consists of a set of routing rules that are evaluated in order. Red Hat OpenShift Service Mesh matches each given request to the virtual service to a specific real destination within the mesh.

Without virtual services, Red Hat OpenShift Service Mesh distributes traffic using round-robin load balancing between all service instances. With a virtual service, you can specify traffic behavior for one or more hostnames. Routing rules in the virtual service tell Red Hat OpenShift Service Mesh how to send the traffic for the virtual service to appropriate destinations. Route destinations can be versions of the same service or entirely different services.

## Weighted Load Balancing

Weighted Load Balancing Requests are forwarded to instances in the pool according to a specific percentage. In this example 80% to v1, 20% to v2.

1. Deploy te weighted load balacing

   ```bash
   cat << EOF | oc create -f -
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: reviews
   spec:
     hosts:
       - reviews
     http:
     - route:
       - destination:
           host: reviews
           subset: v1
         weight: 80
       - destination:
           host: reviews
           subset: v2
         weight: 20
   EOF
   ```

1. **Refresh** the browser tab containing Bookinfo URL a few times and you'll see that occasionally you'll see the v2 of the book review app which has star ratings.

1. **Generate traffic by using the following snippet**

   ```bash
   while true; do curl -sSL "http://$GATEWAY_URL/productpage" | head -n 5; sleep 1; done
   ```

1. Leave the loop running and move onto the next steps.
