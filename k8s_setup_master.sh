#!/bin/bash
# run this script on master node
NUM_NODES=${1:-6}

# setup hostname
sudo hostnamectl set-hostname node-0

# setup master
bash k8s_setup_node.sh
sudo kubeadm config images pull
sudo kubeadm init --pod-network-cidr=10.10.0.0/16 | tee kubeadm-init.log
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# setup worker
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y collectl
bash k8s_setup_worker.sh $NUM_NODES

# setup network plugin
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl taint nodes --all node-role.kubernetes.io/control-plane-