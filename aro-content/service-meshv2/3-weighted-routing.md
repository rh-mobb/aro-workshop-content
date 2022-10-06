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
