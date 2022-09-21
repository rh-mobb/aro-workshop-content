# Red Hat OpenShift Service Mesh
A microservice architecture breaks up the monolith application into many smaller pieces and introduces new communication patterns between services like fault tolerance and dynamic routing.One of the major challenges with the management of a microservices architecture is trying to understand how services are composed, how they are connected and how all the individual components operate, from global perspective and drilling down into particular detail.

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
## Understanding the demo application
**Travel Portal Namespace**
The Travel Demo application simulates two business domains organized in different namespaces.
In a first namespace called travel-portal there will be deployed several travel shops, where users can search for and book flights, hotels, cars or insurance.
The shop applications can behave differently based on request characteristics like channel (web or mobile) or user (new or existing).
These workloads may generate different types of traffic to imitate different real scenarios.
All the portals consume a service called travels deployed in the travel-agency namespace.

**Travel Agency Namespace**
A second namespace called travel-agency will host a set of services created to provide quotes for travel.
A main travels service will be the business entry point for the travel agency. It receives a destination city and a user as parameters and it calculates all elements that compose a travel budget: airfare, lodging, car reservation and travel insurance.
Each service can provide an independent quote and the travels service must then aggregate them into a single response.
Additionally, some users, like registered users, can have access to special discounts, managed as well by an external service.
Service relations between namespaces can be described in the following diagram:
![Demo Diagram](./images/travels-demo-design.png)

**Travel Portal and Travel Agency flow**
A typical flow consists of the following steps:

A portal queries the travels service for available destinations. . Travels service queries the available hotels and returns to the portal shop. . A user selects a destination and a type of travel, which may include a flight and/or a car, hotel and insurance. . Cars, Hotels and Flights may have available discounts depending on user type.

**Travel Control Namespace**
The travel-control namespace runs a business dashboard with two key features:

Allow setting changes for every travel shop simulator (traffic ratio, device, user and type of travel).
Provide a business view of the total requests generated from the travel-portal namespace to the travel-agency services, organized by business criteria as grouped per shop, per type of traffic and per city.
![Travel Dashboard](./images/travels-dashboard.png)
