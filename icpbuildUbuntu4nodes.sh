#!/bin/bash

# This shell should be executer on the MASTER node
# Ubuntu 16.04
# Needs sshpass, args, ICP 3.1.2
# 4 VM should have been prepared before the execution
# Collect IPs and passwords for all VMs


# Credentials variables to be set before execution

MASTERIP=
PASSM=
PROXYIP=
PASSP=
WORKER1IP=
PASSW1=
WORKER2IP=
PASSW2=
PREFIX=

# Script Start point

# Create Credentials
cd /root/.ssh

cat <<END > credentials
root:$PASSM@$MASTERIP
root:$PASSP@$PROXYIP
root:$PASSW1@$WORKER1IP
root:$PASSW2@$WORKER2IP
END

# Create Hosts
echo "127.0.0.1 localhost" > /etc/hosts
echo "$MASTERIP ${PREFIX}m.ibm.ws ${PREFIX}m" >> /etc/hosts
echo "$PROXYIP ${PREFIX}p.ibm.ws ${PREFIX}p" >> /etc/hosts
echo "$WORKER1IP ${PREFIX}w1.ibm.ws ${PREFIX}w1" >> /etc/hosts
echo "$WORKER2IP ${PREFIX}w2.ibm.ws ${PREFIX}w2" >> /etc/hosts

# Install Docker on the master

cat << 'END' > dockerinstall.sh
apt-get -q update
apt-get -y install apt-transport-https ca-certificates curl software-properties-common
sysctl -w vm.max_map_count=262144
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get -q update
apt-get -y install sshpass python-minimal jq
apt-cache madison docker-ce
apt-get -y install docker-ce=18.03.1~ce-0~ubuntu
docker version
END

chmod +x dockerinstall.sh
./dockerinstall.sh

# Download inception
docker pull ibmcom/icp-inception:3.1.2

# Create Keys
mkdir /opt/icp
cd /opt/icp
docker run -e LICENSE=accept -v "$(pwd)":/data ibmcom/icp-inception:3.1.2 cp -r cluster /data
ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N ""
cat ~/.ssh/id_rsa.pub | tee -a ~/.ssh/authorized_keys
systemctl restart sshd
cp ~/.ssh/id_rsa /opt/icp/cluster/ssh_key

# From the boot/master - Install Hosts, Docker, restart SSH and copy keys on each NODE
cd /root/.ssh

tr ':@' '\n' < credentials | xargs -L3 sh -c 'sshpass -p $1 ssh-copy-id -o StrictHostKeyChecking=no -f $0@$2'
tr ':@' '\n' < credentials | xargs -L3 sh -c 'ssh -o StrictHostKeyChecking=no $0@$2 systemctl restart sshd'
tr ':@' '\n' < credentials | xargs -L3 sh -c 'scp -o StrictHostKeyChecking=no /etc/hosts $0@$2:/etc/hosts'
tr ':@' '\n' < credentials | xargs -L3 sh -c 'scp -o StrictHostKeyChecking=no /root/.ssh/dockerinstall.sh $0@$2:/root/.ssh/dockerinstall.sh'
tr ':@' '\n' < credentials | xargs -L3 sh -c 'ssh -o StrictHostKeyChecking=no $0@$2 ./.ssh/dockerinstall.sh'


# Customize hosts
cat <<END > /opt/icp/cluster/hosts
[master]
$MASTERIP

[worker]
$WORKER1IP
$WORKER2IP

[proxy]
$PROXYIP

[management]
$MASTERIP
END

# configure ICP
cd /opt/icp/cluster
sed -i "s/cluster_name: mycluster/cluster_name: $CLUSTERNAME/g" /opt/icp/cluster/config.yaml
sed -i "s/# default_admin_password:/default_admin_password: $CLUSTERPASS/g" /opt/icp/cluster/config.yaml
echo "password_rules:" >> /opt/icp/cluster/config.yaml
echo "- '(.*)'" >> /opt/icp/cluster/config.yaml

# Installation ICP
cd /opt/icp/cluster
docker run -e LICENSE=accept --net=host -t -v "$(pwd)":/installer/cluster ibmcom/icp-inception:3.1.2 install

# Install kubctl
docker run -e LICENSE=accept --net=host -v /usr/local/bin:/data ibmcom/icp-inception:3.1.2 cp /usr/local/bin/kubectl /data

# Connection to ICP on the master
cd /root

cat << 'EOF' > connect2icp.sh
CLUSTERNAME=mycluster
ACCESS_IP=`curl ifconfig.co`
USERNAME=admin
PASSWD=admin
token=$(curl -s -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" -d "grant_type=password&username=$USERNAME&password=$PASSWD&scope=openid" https://$ACCESS_IP:8443/idprovider/v1/auth/identitytoken --insecure | jq .id_token | awk  -F '"' '{print $2}')
kubectl config set-cluster $CLUSTERNAME.icp --server=https://$ACCESS_IP:8001 --insecure-skip-tls-verify=true
kubectl config set-context $CLUSTERNAME.icp-context --cluster=$CLUSTERNAME.icp
kubectl config set-credentials admin --token=$token
kubectl config set-context $CLUSTERNAME.icp-context --user=admin --namespace=default
kubectl config use-context $CLUSTERNAME.icp-context
EOF

chmod +x connect2icp.sh
./connect2icp.sh

# CLI installation

curl -kLo cloudctl-linux-amd64-3.1.2-715 https://ipaddress:8443/api/cli/cloudctl-linux-amd64

curl -fsSL https://clis.ng.bluemix.net/install/linux | sh
chmod 755 /root/cloudctl-linux-amd64-3.1.2-715
mv /root/cloudctl-linux-amd64-3.1.2-715 /usr/local/bin/cloudctl
cloudctl login -a https://mycluster.icp:8443 --skip-ssl-validation -u admin -p admin -c "mycluster Account" -n default
cd
curl -O https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
tar -vxhf helm-v2.9.1-linux-amd64.tar.gz
export PATH=/root/linux-amd64:$PATH
helm init --client-only
helm version --tls
docker login mycluster.icp:8500 -u admin -p admin

# Persistent Volumes creation

cd /tmp
mkdir data01

cat <<EOF | kubectl create -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostpath-pv-once-test1
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 30Gi
  hostPath:
    path: /tmp/data01
  persistentVolumeReclaimPolicy: Recycle
EOF

cat <<EOF | kubectl create -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostpath-pv-many-test1
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 50Gi
  hostPath:
    path: /tmp/data01
  persistentVolumeReclaimPolicy: Recycle
EOF

# Helm Install 

cd
curl -O https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
tar -vxhf helm-v2.9.1-linux-amd64.tar.gz
export PATH=/root/linux-amd64:$PATH
export HELM_HOME=/root/.helm
helm init --client-only
helm version --tls
docker login mycluster.icp:8500 -u admin -p admin

# Change the number of pods per core to avoid insufficient pods

cd
rm test.yaml
cp /etc/cfc/kubelet/kubelet-service-config ./kubelet-dynamic-config
sed -i 's/podsPerCore: 10/podsPerCore: 80/g' ./kubelet-dynamic-config
kubectl -n kube-system create configmap my-node-config --from-file=kubelet=kubelet-dynamic-config --append-hash -o yaml > test.yaml 
CONFIG_MAP_NAME=`grep '/api/v1/namespaces/kube-system/configmaps/' test.yaml | tail -n1 | cut -c 55-`

echo $CONFIG_MAP_NAME

kubectl patch node ${MASTERIP} -p "{\"spec\":{\"configSource\":{\"configMap\":{\"name\":\"${CONFIG_MAP_NAME}\",\"namespace\":\"kube-system\",\"kubeletConfigKey\":\"kubelet\"}}}}"
kubectl patch node ${PROXYIP} -p "{\"spec\":{\"configSource\":{\"configMap\":{\"name\":\"${CONFIG_MAP_NAME}\",\"namespace\":\"kube-system\",\"kubeletConfigKey\":\"kubelet\"}}}}"
kubectl patch node ${WORKER1IP} -p "{\"spec\":{\"configSource\":{\"configMap\":{\"name\":\"${CONFIG_MAP_NAME}\",\"namespace\":\"kube-system\",\"kubeletConfigKey\":\"kubelet\"}}}}"
kubectl patch node ${WORKER2IP} -p "{\"spec\":{\"configSource\":{\"configMap\":{\"name\":\"${CONFIG_MAP_NAME}\",\"namespace\":\"kube-system\",\"kubeletConfigKey\":\"kubelet\"}}}}"


# END OF SCRIPT
