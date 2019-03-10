
#!/bin/bash

# This shell should be executer on the MASTER node
# ICP 3.1.2 - Docker 18.03.1 - RHEL 7

# Variables to be provided before you run this script

export NFIP=192.168.61.107    # NFS server
export NFPW=password
export MAIP=192.168.61.108    # Master
export MAPW=password
export MGIP=192.168.61.109    # Management
export MGPW=password
export PXIP=192.168.61.110    # Proxy
export PXPW=password

export W1IP=192.168.61.190    # Workers
export W1PW=password
export W2IP=192.168.61.191
export W2PW=password
export W3IP=192.168.61.192
export W3PW=password
export W4IP=192.168.61.193
export W4PW=password

export PREFIX=dsname          # used for hostnames in /etc/hosts
export CLUSTERNAME=mycluster
export CLUSTERPASS=admin1!

# Create Credentials (excluding Master)
# This file will be used to remotely customize all nodes (except the master)

cd /root/.ssh
cat <<END > credentials
root:$NFPW@$NFIP
root:$MGPW@$MGIP
root:$PXPW@$PXIP
root:$W1PW@$W1IP
root:$W2PW@$W2IP
root:$W3PW@$W3IP
root:$W4PW@$W4IP
END

# Create /etc/hosts on the master

echo "127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4" > /etc/hosts
echo "$NFIP ${PREFIX}nfs" >> /etc/hosts
echo "$MAIP ${PREFIX}master" >> /etc/hosts
echo "$MGIP ${PREFIX}management" >> /etc/hosts
echo "$PXIP ${PREFIX}proxy" >> /etc/hosts
echo "$W1IP ${PREFIX}worker1" >> /etc/hosts
echo "$W2IP ${PREFIX}worker2" >> /etc/hosts
echo "$W3IP ${PREFIX}worker3" >> /etc/hosts
echo "$W4IP ${PREFIX}worker4" >> /etc/hosts



# Create Docker install script on the master

cd /root
cat << 'END' > dockerinstall.sh
yum check-update -y
yum install -y wget nano nfs-utils yum-utils device-mapper-persistent-data lvm2 sshpass nfs-common jq
wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum install -y http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.68-1.el7.noarch.rpm
yum -y install epel-release-latest-7.noarch.rpm 
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum check-update -y
yum install -y docker-ce-18.03.1.ce-1.el7.centos
systemctl start docker
systemctl stop firewalld
systemctl disable firewalld
docker version
yum check-update -y
END

# Install Docker on the master

chmod +x dockerinstall.sh
./dockerinstall.sh


# Upload installation file to the Master in /root
scp /Users/phil/Downloads/ibm-cloud-private-x86_64-3.1.2.tar.gz root@192.168.61.108:/root
cd /root
tar xf ibm-cloud-private-x86_64-3.1.2.tar.gz -O | docker load

# Copy Config Files to the cluster dir
mkdir /opt/icp
cd /opt/icp
docker run -v $(pwd):/data -e LICENSE=accept ibmcom/icp-inception-amd64:3.1.2-ee cp -r cluster /data

# Create Keys 
ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N ""
cat ~/.ssh/id_rsa.pub | tee -a ~/.ssh/authorized_keys
systemctl restart sshd
cp ~/.ssh/id_rsa /opt/icp/cluster/ssh_key


# Copy the installation file to images dir
cd /opt/icp
mkdir -p cluster/images
mv /root/ibm-cloud-private-x86_64-3.1.2.tar.gz  cluster/images/


# From the master - Customize & Install etc/hosts, Docker, restart SSH and copy keys on each NODE
cd /root/.ssh

tr ':@' '\n' < credentials | xargs -L3 sh -c 'sshpass -p $1 ssh-copy-id -o StrictHostKeyChecking=no -f $0@$2'
tr ':@' '\n' < credentials | xargs -L3 sh -c 'ssh -o StrictHostKeyChecking=no $0@$2 systemctl restart sshd'
tr ':@' '\n' < credentials | xargs -L3 sh -c 'scp -o StrictHostKeyChecking=no /etc/hosts $0@$2:/etc/hosts'
tr ':@' '\n' < credentials | xargs -L3 sh -c 'scp -o StrictHostKeyChecking=no /root/.ssh/dockerinstall.sh $0@$2:/root/.ssh/dockerinstall.sh'
tr ':@' '\n' < credentials | xargs -L3 sh -c 'ssh -o StrictHostKeyChecking=no $0@$2 ./.ssh/dockerinstall.sh'


# Customize cluster hosts file before installing ICP
cat <<END > /opt/icp/cluster/hosts
[master]
$MAIP

[worker]
$W1IP
$W2IP
$W3IP
$W4IP

[proxy]
$PXIP

[management]
$MGIP

[va]
$MAIP
END

# configure ICP
cd /opt/icp/cluster
sed -i "s/cluster_name: mycluster/cluster_name: $CLUSTERNAME/g" /opt/icp/cluster/config.yaml
sed -i 's/vulnerability-advisor: disabled/vulnerability-advisor: enabled/g' /opt/icp/cluster/config.yaml
sed -i "s/# default_admin_password:/default_admin_password: $CLUSTERPASS/g" /opt/icp/cluster/config.yaml
echo "password_rules:" >> /opt/icp/cluster/config.yaml
echo "- '(.*)'" >> /opt/icp/cluster/config.yaml


# Installation ICP
cd /opt/icp/cluster
docker run --net=host -t -e LICENSE=accept -v "$(pwd)":/installer/cluster ibmcom/icp-inception-amd64:3.1.2-ee install

# Install CLIs
# Kubectl
docker run --net=host -t -e LICENSE=accept -v /usr/local/bin:/data ibmcom/icp-inception-amd64:3.1.2-ee cp /usr/local/bin/kubectl /data
# Cloudctl
cd /root
curl -kLo cloudctl-linux-amd64-3.1.2-1203 https://$MAIP:8443/api/cli/cloudctl-linux-amd64
chmod 755 /root/cloudctl-linux-amd64-3.1.2-1203
mv /root/cloudctl-linux-amd64-3.1.2-1203 /usr/local/bin/cloudctl

# Connect2ICP
cat << 'EOF' > connect2icp.sh
#!/bin/bash
token=$(curl -s -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" -d "grant_type=password&username=admin&password=$CLUSTERPASS&scope=openid" https://$MAIP:8443/idprovider/v1/auth/identitytoken --insecure | jq .id_token | awk  -F '"' '{print $2}')
kubectl config set-cluster $CLUSTERNAME.icp --server=https://$MAIP:8001 --insecure-skip-tls-verify=true
kubectl config set-context $CLUSTERNAME.icp-context --cluster=$CLUSTERNAME.icp
kubectl config set-credentials admin --token=$token
kubectl config set-context $CLUSTERNAME.icp-context --user=admin --namespace=default
kubectl config use-context $CLUSTERNAME.icp-context
EOF

# Use CLIs
chmod +x connect2icp.sh
./connect2icp.sh
cloudctl login -a https://$CLUSTERNAME.icp:8443 --skip-ssl-validation -u admin -p $CLUSTERPASS -n default

# Install HELM
cd
curl -O https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
tar -vxhf helm-v2.9.1-linux-amd64.tar.gz
export PATH=/root/linux-amd64:$PATH
export HELM_HOME=/root/.helm
helm init --client-only
helm version --tls
docker login mycluster.icp:8500 -u admin -p $CLUSTERPASS

# Check NFS (install NFS_utils for yum or apt)
# Add a rule in the ClusterImagePolicy

cat <<EOF | kubectl create -f -
apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
kind: ClusterImagePolicy
metadata:
  name: my-cluster-images-nfs-client
spec:
  repositories:
    - name: quay.io/external_storage/*
EOF


helm repo update
helm install -n nfsprovisioner --set podSecurityPolicy.enabled=true --set nfs.server=$NFIP --set nfs.path=/data stable/nfs-client-provisioner --tls

# END OF INSTALLATION














