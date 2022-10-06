## Configuring virtual services
Requests are routed to services within a service mesh with virtual services. Each virtual service consists of a set of routing rules that are evaluated in order. Red Hat OpenShift Service Mesh matches each given request to the virtual service to a specific real destination within the mesh.

Without virtual services, Red Hat OpenShift Service Mesh distributes traffic using round-robin load balancing between all service instances. With a virtual service, you can specify traffic behavior for one or more hostnames. Routing rules in the virtual service tell Red Hat OpenShift Service Mesh how to send the traffic for the virtual service to appropriate destinations. Route destinations can be versions of the same service or entirely different services.

## Weighted Load Balancing
Weighted: Requests are forwarded to instances in the pool according to a specific percentage.

 1. Deploy virtual service.
 
 ***virtual-service-reviews-80-20.yaml***

```bash
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
```
```bash
oc apply -f https://raw.githubusercontent.com/rh-mobb/aro-hackathon-content/main/aro-content/assets/virtual-service-reviews-80-20.yaml
```

2. **Refresh** Bookinfo URL and view changes in traffic for reviews app on the **Graph tab** in **Kiali.**
