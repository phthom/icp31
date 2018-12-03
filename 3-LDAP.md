

![icp000](images/icp000.png)

---

![](./images/ldap.png)



# LDAP Lab

The purpose of this lab is to quickly demonstrate how to install and connect Open LDAP to IBM Cloud Private to control access of all the different kinds of administrator. 

We cover 5 steps :
- Check helm
- Installing Open LDAP thru a helm chart in ICP
- Configure and connect the created LDAP to ICP Authentication components
- Create a team with specific user IDs and roles
- Connect with one of the user IDs and test your authorizations


> **Prerequisites** : you should be logged on your VM and connected to your ICP master.


### Table of Contents

---
- [Task 1: Check helm](#task-1--check-helm)
- [Task 2: Install Open LDAP](#task-2--install-open-ldap)
- [Task3: Connect Open LDAP to ICP](#task3--connect-open-ldap-to-icp)
- [Task4: Create a Team](#task4--create-a-team)
- [Task5: Check Roles](#task5--check-roles)
- [Congratulations](#congratulations)
---


# Task 1: Check helm

We are about to install Open LDAP thru a helm package. 
Before starting this step, we should have a valid helm configuration. 
Here are some steps you need to flow to check helm : 

`helm version --tls`

Results should be :

```console
# helm version --tls
Client: &version.Version{SemVer:"v2.9.1", GitCommit:"20adb27c7c5868466912eebdf6664e7390ebe710", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.9.1+icp", GitCommit:"843201eceab24e7102ebb87cb00d82bc973d84a7", GitTreeState:"clean"}
```

**If you get this valid answer, then skip the rest of the section Task1.**

If you get the following answer:
```console
# helm version --tls
helm: command not found
```

Then install helm:

```console
cd
curl -O https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
tar -vxhf helm-v2.9.1-linux-amd64.tar.gz
export PATH=/root/linux-amd64:$PATH
```

This command will download the helm file to /usr/local/bin directory.

Set an environment variable:

```console
export HELM_HOME=/root/.helm
```

Then init helm:

`helm init --client-only`

Results:
```console
# helm init --client-only
Creating /root/.helm/repository
Creating /root/.helm/repository/cache
Creating /root/.helm/repository/local
Creating /root/.helm/plugins
Creating /root/.helm/starters
Creating /root/.helm/cache/archive
Creating /root/.helm/repository/repositories.yaml
Adding stable repo with URL: https://kubernetes-charts.storage.googleapis.com
Adding local repo with URL: http://127.0.0.1:8879/charts
$HELM_HOME has been configured at /root/.helm.
Not installing Tiller due to 'client-only' flag having been set
Happy Helming!

```

After you have initialize helm client. Try the following command to see the version:

`helm version --tls`

Results :

```console
# helm version --tls
Client: &version.Version{SemVer:"v2.9.1", GitCommit:"20adb27c7c5868466912eebdf6664e7390ebe710", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.9.1+icp", GitCommit:"843201eceab24e7102ebb87cb00d82bc973d84a7", GitTreeState:"clean"}
```
> The helm Client and server should be the same version (i.e. **version 2.9.1**)
> If you get some X509 error the also type that command:

`cp ~/.kube/mycluster/*.pem ~/.helm/`



For the next exercise, we need to get access to the IBM Cloud Private Registry. To do so,  login to the private registry:

`docker login mycluster.icp:8500 -u admin -p admin`

Results:

```console
# docker login mycluster.icp:8500 -u admin -p admin
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
Login Succeeded
```



# Task 2: Install Open LDAP

Get the source code of the helm chart for Open LDAP taht we are going to install our cluster. 

```
git clone https://github.com/ibm-cloud-architecture/icp-openldap.git openldap
```
> Note : don't change the name of the directory (**openldap**) created 

A new directory **openldap** is created.

Package the helm chart using the helm cli:

`helm package openldap`

Results:
```console 
# helm package openldap
Successfully packaged chart and saved it to: /root/openldap-0.1.5.tgz
```

If you have not, log in to your cluster from the IBM Cloud Private CLI and log in to the Docker private image registry. 

`docker login mycluster.icp:8500 -u admin -p admin`

`cloudctl login -a https://mycluster.icp:8443 --skip-ssl-validation`

> Use the admin/admin credentials and choose **1** and **default**.

Populate the Helm chart in the IBM Cloud Private catalog :

```
cloudctl catalog load-chart --archive /root/openldap-0.1.5.tgz 
```

Results:
```console 
# cloudctl catalog load-chart --archive /root/openldap-0.1.5.tgz
Loading helm chart
Loaded helm chart

Synch charts
Synch started
OK
```

Before we can use this archive to create a LDAP instance, we need to be sure that we will not have any security issue. In IBM Cloud Private solution, IBM has implemented the **Cluster Image Policy**.

For each image in a repository, an image policy scope of either `cluster` or `namespace` is applied. When you deploy an application, IBM Container Image Security Enforcement checks whether the Kubernetes namespace that you are deploying to has any policy regulations that must be applied. If a `namespace`policy does not exist, then the `cluster` policy is applied. If neither a `cluster` or `namespace` scope policy exist, your deployment fails to launch.

By default this feature is active and we need to authorize the images that we want to load in a POD.

We are going to use the ICP management Console:

https://icpaddress:8443

Login to the console with admin/admin. 

To add a <u>Cluster Image Policy</u>, go to the **Menu > Manage > Resource Security**

![image-20181128220823372](images/image-20181128220823372.png)

You can have a look at the existing default policy:

![image-20181128221015408](images/image-20181128221015408.png)

In that policy, you will find a list of registries where our cluster is authorized to pull some images:

![image-20181128221209851](images/image-20181128221209851.png)

Click back to **Image Policy**

Now let's add a new policy for our LDAP image and click on the **Create Image Policy**:

![image-20181128221426344](images/image-20181128221426344.png)

Fill the field as follow for the step 1:

![image-20181128221554295](images/image-20181128221554295.png)

Then click on **add registry button**:

![image-20181128221706199](images/image-20181128221706199.png)

And type: 

`docker.io/osixia*`

Result:

![image-20181128221843579](images/image-20181128221843579.png)



Click **Add**. And Click **Add** a second time to add the policy:

![image-20181128222007755](images/image-20181128222007755.png)



Go to the Catalog.
Type **open** in the search zone to retrieve openldap package.

![ldapcatalog](./images/ldapcatalog.png)


Click on **openldap** and **Configure** to see the parameters.
Add a release name **openldap** and the **default** namespace. 

![ldapinstall](./images/ldapinstall.png)

Click **Install**. Then Click **View Helm Releases**.

![ldapcheck](./images/ldapcheck.png)

> Note : The Available Column should be **1**.

Take a note of the **ClusterIP** for a future use:

![ldapclusterip](./images/ldapclusterip.png)

To get access to the Open LDAP portal, use the following URL (where the i-address is the VM ip address):

http://ipaddress:31080

![ldaplogin](./images/ldaplogin.png)

Click on Login and type the following credentials :
user:
`cn=admin,dc=local,dc=io` 
password:
`admin`

You should see the following page:

![ldaplogin2](./images/ldaplogin2.png)

> Note : 4 users have been pre-populated.

See below the **user1**:
![ldapuser](./images/ldapuser.png)


# Task3: Connect Open LDAP to ICP

Now we need to connect our newly created Open LDAP to ICP Authentication Component.
To do so, from the ICP console, Navigate to **Manage > Identity and Access > Authentication**: 

![ldapuser](./images/ldapauthen.png)

Click on the **Set up the connection** link.

Then enter some details:

**LDAP Connection**
- Name: ldap
- Type: Custom

![image-20181128223357837](images/image-20181128223357837.png)



**LDAP authentication**

- Base DN: `dc=local,dc=io` (default value, adjust as needed)
- Bind DN: `cn=admin,dc=local,dc=io` (default value, adjust as needed)
- Admin Password: `admin` (default value, adjust as needed)

![image-20181128223524373](images/image-20181128223524373.png)



**LDAP URL**

- URL: `ldap://clusterip:389` (use the IP address we collected in task2)

![image-20181128223746848](images/image-20181128223746848.png)



Click on **Test Connection** button to check the connection. You should get a green tick.

![image-20181128223911365](images/image-20181128223911365.png)

Then modify the filters:

**LDAP Filters**

- Group filter: `(&(cn=%v)(objectclass=groupOfUniqueNames))`
- User filter: `(&(uid=%v)(objectclass=person))`
- Group ID map: `*:cn`
- User ID map: `*:uid`
- Group member ID map: `groupOfUniqueNames:uniquemember`

![image-20181128224115403](images/image-20181128224115403.png)

Then Click on **Connect**. If no error, then the following list should appear:

![image-20181128224253429](images/image-20181128224253429.png)



Our new Open LDAP is now connected to the ICP Cluster.

# Task4: Create a Team

From the ICP console, Navigate to **Menu > Manage >  Identity and Access > Teams** and click on the link **Create a Team**:

![ldapteams](./images/ldapteams.png)

Enter a team name : **myteam**
Click on the **users** button. Enter **user** in the search field. Check all 4 users to be part of the team. Then choose some **roles** as shown below.

![ldapteams](./images/ldapteams2.png)

Click **Create**

![ldapteams](./images/ldapteams3.png)

Now our team is ready to support login in ICP. 

# Task5: Check Roles

**Log out** from the ICP Console.

**Log in ** again to the ICP Console with the Cluster Admin role :
User ID : `user1`
Password : `ChangeMe`

Check some menu (we should have complete access to all menus)

**Log out** from the ICP Console.

**Log in ** again to the ICP Console with the viewer role :
User ID : `user4`
Password : `ChangeMe`

Check the Image Container menu and you should receive:

![image-20181128225554063](images/image-20181128225554063.png)

If you are interested in the different roles, look at the following link:

https://www.ibm.com/support/knowledgecenter/en/SSBS6K_3.1.0/user_management/assign_role.html

# Congratulations 

You have successfully installed, deployed an OPEN LDAP using helm and then you ahve customized the LDAP connection to ICP. Finally you successfully customized different roles for different users in one team in an **IBM Cloud Private** cluster.

----

![icp000](images/icp000.png)

