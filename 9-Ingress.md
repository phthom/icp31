



![icp000](images/icp000.png)



# Using the Ingress Control as a Router in ICP



### Creating a simple Node.js Express application

To demonstrate the power of **Ingress** controllers, I want to create a basic Express application written using Node.js that is easy to write and explain for this article.   In the application, I have defined two Express routes that return a message back to the user with a user provided payload appended to the end.    These two routes will respond based upon the match of either `foo` or `helloworld`.

**server.js**

```
const express = require('express')
const app = express()

app.get('/helloworld/:id', function (request, response) {
 response.send('Hello World! ' + request.params.id);
});

app.get('/foo/:id', function (request, response) {
 response.send('Testing foo:  ' + request.params.id);
});

app.listen(9080, function () {
 console.log('Example app listening on port 9080!')
});
```




As this application has a dependency on Express, I will add this dependency to my package.json of my application.  This will be used later on when packaging my Docker image and deploying to IBM Cloud Private.

**package.json**

```
{
 "name": "nodejs",
 "version": "1.0.0",
 "main": "server.js",
 "dependencies": {
 "express": "^4.15.3"
 },
 "devDependencies": {},
 "scripts": {
 "test": "echo \"Error: no test specified\" && exit 1",
 "start": "node server.js"
 },
 "author": "",
 "license": "ISC",
 "description": ""
}

```



### Pushing the application to Docker Hub

Now that we have created the script and done some local testing, we are now ready to package this and push the image to Docker Hub (or whatever registry you choose to leverage).   To publish the image, we need to define the Dockerfile which we will use to build and publish the artifact.

The Dockerfile I am using is a standard Dockerfile that packages the depedencies and the main entry point into the application named server.js

**Dockerfile**

```
FROM node:latest

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Install app dependencies
COPY package.json /usr/src/app/
RUN npm install

# Bundle app source
COPY ./server.js /usr/src/app

EXPOSE 9080
CMD [ "npm", "start" ]
```



To package the container and publish the image, type the following commands:

```
docker login mycluster.icp:8500 -u admin -p admin
docker build --no-cache=true -t mycluster.icp:8500/default/node-ingress:v2 .
docker push mycluster.icp:8500/default/node-ingress:v2

```



### Deploying application to IBM Cloud Private

We are now at the point where we can deploy the resource to IBM Cloud Private.  Since we want to deploy this as a Kubernetes resource, we need to first define the Deployment yaml file that will not only create the deployment artifact but also will create the service.

**deployment.yaml**

```
apiVersion: v1
kind: Service
metadata:
 name: node-app
 labels:
   app: node-app
   version: v2
spec:
 ports:
 - port: 9080
   name: http
 selector:
   app: node-app
   version: v2
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
 name: node-app
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: node-app
        version: v2
    spec:
      containers:
      - image: mycluster.icp:8500/default/node-ingress:v2
        imagePullPolicy: IfNotPresent
        name: node-app
        ports:
        - containerPort: 9080
---
```



Now that the we have defined the Service and Deployment types for this deployment, we can now run the command `kubectl apply -f deployment.yaml` that will deploy this application to IBM Cloud Private.   Once the pods have listed as running (you can verify using the command `kubectl get pods` and look for the prefix node-app).   Once the status is running, we are ready for the next step of configuring the Ingress.

```
# kubectl apply -f ingress.yaml
ingress.extensions/test-ingress created
```



### Defining ingress rules

We are now ready to define our Ingress.  Ingress is a great way to provide a single point of entry for your Kubernetes resources.   Ingresses such as Nginx provide features such as SSL termination, URL rewriting and a host of other features that are found in many proxies in the market today.   In this section,  we will define a set of rules that will route our two Express routes from the Ingress to our application using our ingress.yaml.

ingress.yaml

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
 name: test-ingress
spec:
  rules:
  - http:
      paths:
      - path: /foo
        backend:
         serviceName: node-app
         servicePort: 9080
      - path: /helloworld
        backend:
          serviceName: node-app
          servicePort: 9080
---
```



Now that the we have defined the ingress resource, we can now run the command `kubectl apply -f ingress.yaml` which will configure the ingress to route requests to our application.

To verify this is working, locate the proxy node of your deployment and find the ip address for this deployment.   In the example I provided, I set PROXY to the proxy node of my IBM Cloud Private deployment.  Once you have that value, you can curl the various REST APIs as follows…

```
export PROXY=https://169.51.44.149

# curl -k $PROXY/helloworld/todd; echo
Hello World! todd
# curl -k $PROXY/helloworld/phil; echo
Hello World! phil

# curl -k $PROXY/foo/bar; echo
Testing foo:  bar

```

You can also go to your browser and type `https://ipaddress//helloworld/phil`

![image-20181206122129771](images/image-20181206122129771.png)

#### Enabling access logging

The final step to tie all of the pieces together is to enable **access logging**.  By default, IBM Cloud Private has disabled access logging but provides a simple way to enable it by editing one of the IBM Cloud Private **ConfigMap** resources.

To enable access logging, edit the ConfigMap resource **nginx-ingress-controller**.   To edit this resource, go to the command line and use the following command.

In this resource, change the disable-access-log parameter to **false.**

```
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  disable-access-log: "false"
  keep-alive-requests: "10000"
  upstream-keepalive-connections: "64"
kind: ConfigMap
metadata:
  creationTimestamp: 2018-12-04T13:56:26Z
  name: nginx-ingress-controller
  namespace: kube-system
  resourceVersion: "877"
  selfLink: /api/v1/namespaces/kube-system/configmaps/nginx-ingress-controller
  uid: 64b6d6b6-f7cc-11e8-b645-06a6842645b2
```



Once this is changed, save the file for the change to take effect.

Now that this change has been made, let’s repeat the same CURL commands we did previously.

```
curl -k $PROXY/helloworld/todd; echo
curl -k $PROXY/helloworld/phil; echo
curl -k $PROXY/foo/bar; echo
curl -k $PROXY/helloworld/todd; echo
curl -k $PROXY/helloworld/phil; echo
curl -k $PROXY/foo/bar; echo
curl -k $PROXY/helloworld/todd; echo
curl -k $PROXY/helloworld/phil; echo
curl -k $PROXY/foo/bar; echo
curl -k $PROXY/helloworld/todd; echo
curl -k $PROXY/helloworld/phil; echo
curl -k $PROXY/foo/bar; echo
curl -k $PROXY/helloworld/todd; echo
curl -k $PROXY/helloworld/phil; echo
curl -k $PROXY/foo/bar; echo
```

And now we can view the logs for the pod.   In IBM Cloud Private, the pod name for the Ingress starts with nginx-ingress.   You can list the pods **`kubectl get pods –namespace=kube-system`** to find the list of pods.

`kubectl get pods -n=kube-system | grep nginx`

Results:

```
# kubectl get pods -n=kube-system | grep nginx
nginx-ingress-controller-smzfw  
```

Once I located my pod, I ran the following command:

`kubectl logs nginx-ingress-controller-smzfw  -n=kube-system`

Results:

```
# kubectl logs nginx-ingress-controller-smzfw  -n=kube-system
-------------------------------------------------------------------------------
NGINX Ingress controller
  Release:    0.16.2
  Build:      git-26eacf4
  Repository: https://github.com/kubernetes/ingress-nginx
-------------------------------------------------------------------------------

nginx version: nginx/1.13.12
W1204 13:57:00.371744       7 client_config.go:533] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.
I1204 13:57:00.371999       7 main.go:183] Creating API client for https://10.0.0.1:443
I1204 13:57:00.382626       7 main.go:227] Running in Kubernetes cluster version v1.11 (v1.11.1+icp) - git (clean) commit 90febef3a98de5efb2e1248525e24a57e01ad386 - platform linux/amd64
I1204 13:57:00.384431       7 main.go:100] Validated kube-system/default-backend as the default backend.
I1204 13:57:00.613457       7 nginx.go:250] Starting NGINX Ingress controller
I1204 13:57:00.622823       7 event.go:218] Event(v1.ObjectReference{Kind:"ConfigMap", Namespace:"kube-system", Name:"nginx-ingress-controller", UID:"64b6d6b6-f7cc-11e8-b645-06a6842645b2", APIVersion:"v1", ResourceVersion:"877", FieldPath:""}): type: 'Normal' reason: 'CREATE' ConfigMap kube-system/nginx-ingress-controller

```

```
127.0.0.1 - [127.0.0.1] - - [04/Dec/2018:19:09:56 +0000] "GET /foo/bar HTTP/1.1" 200 17 "-" "curl/7.47.0" 84 0.002 [default-node-app-9080] 10.1.155.63:9080 17 0.000 200 20a11ce132da4abe937a1e4e8063f4c8
127.0.0.1 - [127.0.0.1] - - [04/Dec/2018:19:09:56 +0000] "GET /helloworld/todd HTTP/1.1" 200 17 "-" "curl/7.47.0" 92 0.002 [default-node-app-9080] 10.1.155.63:9080 17 0.000 200 ed9189f09bb13074f16cdb97785dda9b
127.0.0.1 - [127.0.0.1] - - [04/Dec/2018:19:09:56 +0000] "GET /helloworld/phil HTTP/1.1" 200 17 "-" "curl/7.47.0" 92 0.003 [default-node-app-9080] 10.1.155.63:9080 17 0.004 200 e6e44fe15543cd32c40f88eb555eea07
127.0.0.1 - [127.0.0.1] - - [04/Dec/2018:19:09:56 +0000] "GET /foo/bar HTTP/1.1" 200 17 "-" "curl/7.47.0" 84 0.001 [default-node-app-9080] 10.1.155.63:9080 17 0.000 200 7f78ad639c70b8280c8b181f492d7e9c
127.0.0.1 - [127.0.0.1] - - [04/Dec/2018:19:09:56 +0000] "GET /helloworld/todd HTTP/1.1" 200 17 "-" "curl/7.47.0" 92 0.001 [default-node-app-9080] 10.1.155.63:9080 17 0.000 200 63cb59309032409289e011cb88db4612
127.0.0.1 - [127.0.0.1] - - [04/Dec/2018:19:09:56 +0000] "GET /helloworld/phil HTTP/1.1" 200 17 "-" "curl/7.47.0" 92 0.002 [default-node-app-9080] 10.1.155.63:9080 17 0.000 200 aa5415f457353136b9a37daae56b9dee
127.0.0.1 - [127.0.0.1] - - [04/Dec/2018:19:09:59 +0000] "GET /foo/bar HTTP/1.1" 200 17 "-" "curl/7.47.0" 84 0.002 [default-node-app-9080] 10.1.155.63:9080 17 0.000 200 b8931fddcd5cb123ed56275118af3728
```

You can see all requests incoming thru the ingress controller.

# Conclusion

Successful deployments of large scale applications require transparency and insight of application and their environments.  By enabling access logging, we are able to quickly track the status of our deployments in relation to their HTTP endpoint health status and can easily integrate access logging with our overall logging and monitoring strategy.  In this recipe, we showed how one can take a Node.js application, configure the Ingress to route to this application and ultimate start to track the traffic this application is handling in terms of HTTP requests.   This simple but powerful scenario can easily be scaled up to many enterprise deployments we are seeing on IBM Cloud Private.   



![icp000](images/icp000.png)