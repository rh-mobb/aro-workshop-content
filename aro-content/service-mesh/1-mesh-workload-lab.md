# Red Hat OpenShift Service Mesh
A microservice architecture breaks up the monolith application into many smaller pieces and introduces new communication patterns between services like fault tolerance and dynamic routing.One of the major challenges with the management of a microservices architecture is trying to understand how services are composed, how they are connected and how all the individual components operate, from global perspective and drilling down into particular detail.

Besides the advantages of breaking down services into micro services (like agility, scalability, increased reusability, better testability and easy upgrades and versioning), this paradigm also increases the complexity of securing them due to a shift of the method calls via in-process communication into many separate network requests which need to be secured. Every new service you introduce needs to be protected from man-in-the-middle attacks and data leaks, manage access control, and audit who is using which resources and when. Not forgetting the fact that each service can be written in different programming languages. A Service Mesh like Istio provides traffic control and communication security capabilities at the platform level and frees the application writers from those tasks, allowing them to focus on business logic.

But just because the Service Mesh helps to offload the extra coding, developers still need to observe and manage how the services are communicating as they deploy an application.  With the OpenShift Service Mesh, Kiali has been packaged along with Istio to make that task easier. In this post we will show how to use Kiali capabilities to observe and manage an Istio Service Mesh.

## Install Travel Demo
This demo application will deploy several services grouped into three namespaces.

```bash
oc create namespace travel-agency
oc create namespace travel-portal
oc create namespace travel-control

oc apply -f <(curl -L https://raw.githubusercontent.com/kiali/demos/master/travels/travel_agency.yaml) -n travel-agency
oc apply -f <(curl -L https://raw.githubusercontent.com/kiali/demos/master/travels/travel_portal.yaml) -n travel-portal
oc apply -f <(curl -L https://raw.githubusercontent.com/kiali/demos/master/travels/travel_control.yaml) -n travel-control
```
Check that all deployments rolled out as expected:
```bash
$ oc get deployments -n travel-control
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
control   1/1     1            1           67m

$ oc get deployments -n travel-portal
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
travels   1/1     1            1           67m
viaggi    1/1     1            1           67m
voyages   1/1     1            1           67m

$ oc get deployments -n travel-agency
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
cars-v1         1/1     1            1           68m
discounts-v1    1/1     1            1           68m
flights-v1      1/1     1            1           68m
hotels-v1       1/1     1            1           68m
insurances-v1   1/1     1            1           68m
mysqldb-v1      1/1     1            1           68m
travels-v1      1/1     1            1           68m

```
