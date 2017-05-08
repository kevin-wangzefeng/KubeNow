#!/bin/bash
echo "$(hostname) 127.0.0.1" >> /etc/hosts

sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config


cp -f /home/ubuntu/.ssh/authorized_keys /root/.ssh/
service ssh restart
passwd root<<EOF
root
root
EOF
apt-get update
apt-get install -y python python-pip

# install openstack relevant clients
sudo pip install -U --force 'python-openstackclient==2.4.0'
sudo pip install -U --force 'python-heatclient==1.1.0'
sudo pip install -U --force 'python-swiftclient==3.0.0'
sudo pip install -U --force 'python-glanceclient==2.0.0'
sudo pip install -U --force 'python-novaclient==3.4.0'


# prepare for docker installation
apt-get install -y apt-transport-https

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
# Install docker if you don't have it already.
# Install ebtables socat for kubeadm
apt-get install -y docker-engine ebtables socat

# set private docker registry
cat <<EOF >/etc/docker/daemon.json
{ "insecure-registries":["10.145.208.152:5000"] }
EOF

systemctl restart docker


export CONTROLLER=10.145.208.11

export OS_USER_DOMAIN_NAME=Default
#export OS_PROJECT_DOMAIN_NAME=Default
export OS_PROJECT_NAME=kevin
export OS_USERNAME=kevin
export OS_PASSWORD=kevin
export OS_TENANT_NAME=kevin
export OS_AUTH_URL=http://$CONTROLLER:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_VOLUME_API_VERSION=2
export OS_REGION_NAME=RegionOne

mkdir -p  /home/v1.7.0-test392
swift download v1.7.0-test392 -D /home/v1.7.0-test392

chmod +x -R /home/v1.7.0-test392/node-bins/
mv /home/v1.7.0-test392/node-bins/* /usr/bin

mkdir -p /etc/systemd/system/kubelet.service.d/
mv /home/v1.7.0-test392/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/
mv /home/v1.7.0-test392/kubelet.service /lib/systemd/system/
systemctl daemon-reload

echo "Running on master"
# KUBE_REPO_PREFIX=10.145.208.152:5000 kubeadm --kubernetes-version=v1.7.0-test392 init --token af1abe.18cada885a53ed20
KUBE_REPO_PREFIX=10.145.208.152:5000 kubeadm --kubernetes-version=v1.7.0-test392 init --token ${kubeadm_token}

echo "copy admin.conf to home"
USER=$(whoami)
HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
cp /etc/kubernetes/admin.conf $HOME/
chown $(id -u):$(id -g) $HOME/admin.conf
echo "add env var to bashrc"
cat <<EOF >>$HOME/.bashrc
export KUBECONFIG=$HOME/admin.conf
EOF
