

![icp000](images/icp000.png)

---

![](./images/istio.png)

# Istio Lab

In recent years, with the development of container technology, more enterprise customers are turning to microservices. Microservices are a combination of lightweight and fine-grained services that work cohesively to allow for larger, application-wide functionality. This approach improves modularity and makes applications easier to develop and test when compared to traditional, monolithic application. With the adoption of microservices, new challenges emerge due to a myriad of services that exist in larger systems. Developers must now account for service discovery, load balancing, fault tolerance, dynamic routing, and communication security. Thanks to Istio, we can turn disparate microservices into an integrated service mesh by systemically injecting envoy proxy into the network layers while decoupling the operators to connect, manage, and secure microservices for application feature development.

This lab takes you step-by-step through the installation of Istio and the deployment of microservices-based applications in IBM Cloud Private.

> **Prerequisites** : you should be logged on your VM and connected to your ICP master. Istio should have been installed as part of the installation of ICP 3.1 (istio: enabled)


### Table of Contents

---
- [Task1: Installing Istio on IBM Cloud Private](#task1--installing-istio-on-ibm-cloud-private)
- [Task2 - Deploy the Bookinfo application](#task2---deploy-the-bookinfo-application)
    + [Create Secret](#create-secret)
    + [Prepare the Bookinfo manifest](#prepare-the-bookinfo-manifest)
    + [Automatic Sidecar Injection](#automatic-sidecar-injection)
- [Task3: Access the Bookinfo application](#task3--access-the-bookinfo-application)
- [Task4: Collect Metrics with Prometheus](#task4--collect-metrics-with-prometheus)
- [Task5: Visualizing Metrics with Grafana](#task5--visualizing-metrics-with-grafana)
- [Congratulations](#congratulations)

---



# Introduction

This example deploys a sample application composed of four separate microservices used to demonstrate various Istio features. The application displays information about a book, similar to a single catalog entry of an online book store. Displayed on the page is a description of the book, book details (ISBN, number of pages, and so on), and a few book reviews.

The Bookinfo application is broken into four separate microservices:

- `productpage`. The `productpage` microservice calls the `details` and `reviews` microservices to populate the page.
- `details`. The `details` microservice contains book information.
- `reviews`. The `reviews` microservice contains book reviews. It also calls the `ratings` microservice.
- `ratings`. The `ratings` microservice contains book ranking information that accompanies a book review.

There are 3 versions of the `reviews` microservice:

- Version v1 doesn’t call the `ratings` service.
- Version v2 calls the `ratings` service, and displays each rating as 1 to 5 black stars.
- Version v3 calls the `ratings` service, and displays each rating as 1 to 5 red stars.

To run the sample with Istio requires no changes to the application itself. Instead, we simply need to configure and run the services in an Istio-enabled environment, with Envoy sidecars injected along side each service. The needed commands and configuration vary depending on the runtime environment although in all cases the resulting deployment will look like this:

![image-20181202151511591](images/image-20181202151511591.png)





# Task1: Check Istio on IBM Cloud Private 

Istio has been normal installed during your IBM Cloud Private installation (parameter "istio: enabled" in the config.yaml). You can also install istio after the IBM Cloud Private installation. 

Ensure that the `istio-*` Kubernetes services are deployed before you continue.

```bash
kubectl get svc -n istio-system
```
Output:

```
# kubectl get svc -n istio-system
NAME                       TYPE           CLUSTER-IP   EXTERNAL-IP   PORT(S)                                                                                                     AGE
grafana                    ClusterIP      10.0.0.83    <none>        3000/TCP                                                                                                    15h
istio-citadel              ClusterIP      10.0.0.167   <none>        8060/TCP,9093/TCP                                                                                           15h
istio-egressgateway        ClusterIP      10.0.0.156   <none>        80/TCP,443/TCP                                                                                              15h
istio-galley               ClusterIP      10.0.0.113   <none>        443/TCP,9093/TCP                                                                                            15h
istio-ingressgateway       LoadBalancer   10.0.0.18    <pending>     80:31380/TCP,443:31390/TCP,31400:31400/TCP,15011:30103/TCP,8060:30971/TCP,15030:31418/TCP,15031:31022/TCP   15h
istio-pilot                ClusterIP      10.0.0.237   <none>        15010/TCP,15011/TCP,8080/TCP,9093/TCP                                                                       15h
istio-policy               ClusterIP      10.0.0.150   <none>        9091/TCP,15004/TCP,9093/TCP                                                                                 15h
istio-sidecar-injector     ClusterIP      10.0.0.44    <none>        443/TCP                                                                                                     15h
istio-statsd-prom-bridge   ClusterIP      10.0.0.116   <none>        9102/TCP,9125/UDP                                                                                           15h
istio-telemetry            ClusterIP      10.0.0.140   <none>        9091/TCP,15004/TCP,9093/TCP,42422/TCP                                                                       15h
jaeger-agent               ClusterIP      None         <none>        5775/UDP,6831/UDP,6832/UDP                                                                                  15h
jaeger-collector           ClusterIP      10.0.0.158   <none>        14267/TCP,14268/TCP                                                                                         15h
jaeger-query               ClusterIP      10.0.0.15    <none>        16686/TCP                                                                                                   15h
kiali                      ClusterIP      10.0.0.163   <none>        20001/TCP                                                                                                   15h
kiali-jaeger               NodePort       10.0.0.114   <none>        20002:32439/TCP                                                                                             15h
prometheus                 ClusterIP      10.0.0.70    <none>        9090/TCP                                                                                                    15h
servicegraph               ClusterIP      10.0.0.61    <none>        8088/TCP                                                                                                    15h
tracing                    ClusterIP      10.0.0.207   <none>        16686/TCP                                                                                                   15h
zipkin                     ClusterIP      10.0.0.246   <none>        9411/TCP      
```
  **Note: the istio-ingressgateway service will be in `pending` state with no external ip. That is normal.**

Ensure the corresponding pods `istio-citadel-*`, `istio-ingressgateway-*`, `istio-pilot-*`, and `istio-policy-*` are all in **`Running`** state before you continue.

```
kubectl get pods -n istio-system
```
Output:

```
# kubectl get pods -n istio-system
NAME                                        READY     STATUS    RESTARTS   AGE
grafana-85978b879c-9nqns                    1/1       Running   0          15h
istio-citadel-6f9479b8dc-66hfv              1/1       Running   0          15h
istio-egressgateway-749d798566-8r82s        1/1       Running   0          15h
istio-egressgateway-749d798566-f4j7h        1/1       Running   0          15h
istio-egressgateway-749d798566-h5g77        1/1       Running   0          14h
istio-egressgateway-749d798566-hsf8k        1/1       Running   0          14h
istio-egressgateway-749d798566-ptwr6        1/1       Running   0          15h
istio-galley-6669bbc8d6-8wktj               1/1       Running   0          15h
istio-ingressgateway-8cbfcddf9-5hwl2        1/1       Running   0          14h
istio-ingressgateway-8cbfcddf9-7c7gl        1/1       Running   0          15h
istio-ingressgateway-8cbfcddf9-9gpqp        1/1       Running   0          15h
istio-ingressgateway-8cbfcddf9-9tmhr        1/1       Running   0          15h
istio-ingressgateway-8cbfcddf9-tfxpp        1/1       Running   0          15h
istio-pilot-574d5fbdbb-nf8pd                2/2       Running   0          15h
istio-policy-566796c574-pwrf4               2/2       Running   0          15h
istio-sidecar-injector-6898c4fb69-dhh2l     1/1       Running   0          15h
istio-statsd-prom-bridge-698f997978-z7br9   1/1       Running   0          15h
istio-telemetry-f85db849f-ntmg4             2/2       Running   0          15h
istio-tracing-774696598b-w8r5n              1/1       Running   0          15h
kiali-59557577c6-4rpwn                      1/1       Running   0          15h
prometheus-6465866cd6-ff8dp                 1/1       Running   0          15h
servicegraph-789d9565dd-2jksv               1/1       Running   1          15h
```

Before your continue, make sure all the pods are deployed and **`Running`**. If they're in `pending` state, wait a few minutes to let the deployment finish.

Congratulations! You successfully installed Istio into your cluster.


# Task2 - Deploy the Bookinfo application
If the **control plane** is deployed successfully, you can then start to deploy your applications that are managed by Istio. I will use the **Bookinfo** application as an example to illustrate the steps of deploying applications that are managed by Istio.

### Create Secret

If you are using a private registry for the sidecar image, then you need to create a Secret of type docker-registry in the cluster that holds authorization token, and patch it to your application’s ServiceAccount. Use the following 2 commands:

```bash 
kubectl create secret docker-registry private-registry-key \
  --docker-server=mycluster.icp:8500 \
  --docker-username=admin \
  --docker-password=admin \
  --docker-email=null
```

Then patch the service account:

```bash
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "private-registry-key"}]}'
```

### Prepare the Bookinfo manifest

Return to your directory:

`cd`

Create a new YAML file named **bookinfo.yaml** to save the Bookinfo application manifest.

  ```sh
apiVersion: v1
kind: Service
metadata:
  name: details
  labels:
    app: details
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: details
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: details-v1
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: details
        version: v1
    spec:
      containers:
      - name: details
        image: morvencao/istio-examples-bookinfo-details-v1:1.5.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: v1
kind: Service
metadata:
  name: ratings
  labels:
    app: ratings
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: ratings
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: ratings-v1
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: ratings
        version: v1
    spec:
      containers:
      - name: ratings
        image: morvencao/istio-examples-bookinfo-ratings-v1:1.5.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: v1
kind: Service
metadata:
  name: reviews
  labels:
    app: reviews
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: reviews
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: reviews-v1
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: reviews
        version: v1
    spec:
      containers:
      - name: reviews
        image: morvencao/istio-examples-bookinfo-reviews-v1:1.5.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: reviews-v2
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: reviews
        version: v2
    spec:
      containers:
      - name: reviews
        image: morvencao/istio-examples-bookinfo-reviews-v2:1.5.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: reviews-v3
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: reviews
        version: v3
    spec:
      containers:
      - name: reviews
        image: morvencao/istio-examples-bookinfo-reviews-v3:1.5.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: v1
kind: Service
metadata:
  name: productpage
  labels:
    app: productpage
spec:
  ports:
  - port: 9080
    name: http
  selector:
    app: productpage
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: productpage-v1
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: productpage
        version: v1
    spec:
      containers:
      - name: productpage
        image: morvencao/istio-examples-bookinfo-productpage-v1:1.5.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9080
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: gateway
  annotations:
    kubernetes.io/ingress.class: "istio"
spec:
  rules:
  - http:
      paths:
      - path: /productpage
        backend:
          serviceName: productpage
          servicePort: 9080
      - path: /login
        backend:
          serviceName: productpage
          servicePort: 9080
      - path: /logout
        backend:
          serviceName: productpage
          servicePort: 9080
      - path: /api/v1/products.*
        backend:
          serviceName: productpage
          servicePort: 9080
---
  ```

### Automatic Sidecar Injection
If you have enabled automatic sidecar injection, the istio-sidecar-injector automatically injects Envoy **proxy** containers into your **application pods** that are running in the namespaces, labelled with istio-injection=enabled. For example, let's deploy the Bookinfo application to the default namesapce.

`kubectl label namespace default istio-injection=enabled`

Add an image policy before.

To add a <u>Cluster Image Policy</u>, go to the **Menu > Manage > Resource Security**

![image-20181128220823372](images/image-20181128220823372.png)



Now let's add a new policy for our LDAP image and click on the **Create Image Policy**:

![image-20181128221426344](../../../../IBMCloud%20Private/Workshops/WS-ICP-Dec%202018/LAB/images/image-20181128221426344.png)

Fill the name field with **istiopolicy** 

Then click **add a registry policy** and type : `docker.io/morvencao*`

Finish by clicking **Add** at the top right.

Now, here is the command to inject the sidecar when deploying the application:

`kubectl create -n default -f bookinfo.yaml`

Results:

```console
kubectl create -n default -f bookinfo.yaml
service "details" created
deployment.extensions "details-v1" created
service "ratings" created
deployment.extensions "ratings-v1" created
service "reviews" created
deployment.extensions "reviews-v1" created
deployment.extensions "reviews-v2" created
deployment.extensions "reviews-v3" created
service "productpage" created
deployment.extensions "productpage-v1" created
ingress.extensions "gateway" created
```

To check that the injection was successful, go to ICP console, click on the **Menu>Workload>Deployments**

![image-20181202144556442](images/image-20181202144556442.png)

Go to **productpage** deployment, then **drill down to POD** and then **drill down to containers.** You should have 2 containers in one POD. The istio-proxy is the side-car container running aside the application container. 



![image-20181202144239550](images/image-20181202144239550.png)





# Task3: Access the Bookinfo application

After all pods for the Bookinfo application are in a running state, you can access the Bookinfo **product page**. 

Display the the service:

`kubectl get svc productpage -n default`

Results:

```console
 kubectl get svc productpage
NAME          TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
productpage   ClusterIP   10.0.0.159   <none>        9080/TCP   38m
```
Take a note of your Cluster-IP and port:

`curl -o /dev/null -s -w "%{http_code}\n" http://<clusterIP>:<port>/productpage`

Results:
```console
curl -o /dev/null -s -w "%{http_code}\n" http://10.0.0.159:9080/productpage
200
```
You should get a return code `200`.

Now, use that command to get the URL to get access to product page:
```bash
export BOOKINFO_URL=$(kubectl get po -l istio=ingressgateway -n istio-system -o 'jsonpath={.items[0].status.hostIP}'):$(kubectl get svc istio-ingressgateway -n istio-system -o 'jsonpath={.spec.ports[0].nodePort}')
```

Then use:

`echo $BOOKINFO_URL`

Output:

```console
echo $BOOKINFO_URL
5.10.96.73:31380
```
Use this URL to test the bookinfo application:

`curl -o /dev/null -s -w "%{http_code}\n" http://${BOOKINFO_URL}/productpage`

You should get a return code `200`.

You can also access the Bookinfo product page from the browser by specifying the address: http://${BOOKINFO_URL}/productpage. Try to refresh the page several times, you will see different versions of reviews **randomly** shown in the product page(red stars, black stars, no stars), because I haven’t created any route rule for the Bookinfo application.


# Task4: Collect Metrics with Prometheus

In this section, you can see how to configure Istio to automatically gather telemetry and create new customized telemetry for services. I will use the Bookinfo application as an example.

Istio can enable Prometheus with a service type of ClusterIP. You can also expose another service of type NodePort and then access Prometheus by running the following command:

`kubectl expose service prometheus --type=NodePort  --name=istio-prometheus-svc --namespace istio-system` 

`export PROMETHEUS_URL=$(kubectl get po -l app=prometheus \
​      -n istio-system -o 'jsonpath={.items[0].status.hostIP}'):$(kubectl get svc \
​      istio-prometheus-svc -n istio-system -o 'jsonpath={.spec.ports[0].nodePort}')`
​      
`echo http://${PROMETHEUS_URL}/`       

Results:
```console
echo http://${PROMETHEUS_URL}/
http://5.10.96.73:31316/
```

Use the ${PROMETHEUS_URL} to get access to prometheus from a browser:

Type `istio_response_bytes_sum` in the first field and click execute button:

![prom1](./images/prom1.png)

Move to the right to see the metrics collected:

![prom2](./images/prom2.png)

If you don't see anything, retry the following command several times:
`curl -o /dev/null -s -w "%{http_code}\n" http://clusterip:9080/productpage` 

# Task5: Visualizing Metrics with Grafana

Now I will setup and use the Istio Dashboard to monitor the service mesh traffic. I will use the Bookinfo application as an example.

Similar to Prometheus, Istio enables Grafana with a service type of ClusterIP. You need to expose another service of type NodePort to access Grafana from the external environment by running the following commands:

`kubectl expose service grafana --type=NodePort --name=istio-grafana-svc --namespace istio-system`

```
export GRAFANA_URL=$(kubectl get po -l app=grafana -n \
      istio-system -o 'jsonpath={.items[0].status.hostIP}'):$(kubectl get svc \
      istio-grafana-svc -n istio-system -o \
      'jsonpath={.spec.ports[0].nodePort}')
```

`echo http://${GRAFANA_URL}/``

Results:
```console
echo http://${GRAFANA_URL}
http://5.10.96.73:30915
```
Access the Grafana web page from your browser http://${GRAFANA_URL}/.

By default, Istio grafana has three built-in dashboards: Istio Dashboard, Mixer Dashboard and Pilot Dashboard. Istio Mesh Dashboard is an overall view for all service traffic including high-level HTTP requests flowing and metrics about each individual service call, while Mixer Dashboard and Pilot Dashboard are mainly resources usage overview.

Click on the top left HOME button and you should see all the built-in dashboards:

![prom2](./images/grafana1.png)

The Istio Mesh Dashboard resembles the following screenshot:

![prom2](./images/grafana2.png)


​      



# Congratulations 

You have successfully installed, deployed and customized the **Istio** for an **IBM Cloud Private** cluster.

In this lab, I have gone through how to enable Istio on IBM Cloud Private 2.1.0.3. I also reviewed how to deploy microservice-based application that are managed and secured by Istio. The lab also covered how to manage, and monitor microservices with Istio addons such as Prometheus and Grafana.

Istio solves the microservices mesh tangle challenge by injecting a transparent envoy proxy as a sidecar container to application pods. Istio can collect fine-grained metrics and dynamically modify the routing flow without interfering with the original application. This provides a uniform way to connect, secure, manage, and monitor microservices.

For more information about Istio, see https://istio.io/docs/.

----



![icp000](images/icp000.png)