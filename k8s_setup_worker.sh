#!/bin/bash

# run it on master node, it will automatically add nodes
NUM_NODES=${1:-6}

JOIN_COMMAND=$(grep -A 2 "kubeadm join" kubeadm-init.log | tr -d '\\\n' | xargs)
echo "$JOIN_COMMAND" | tee ~/join-command.sh

for i in $(seq 1 $NUM_NODES); do
    node="node-$i"
    echo "Connecting to $node..."
    (
    # install collectl
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y collectl"
    # setup k8s
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo hostnamectl set-hostname $node"
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ~/join-command.sh $node:~/join-command.sh
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ~/SetupScripts/k8s_setup_node.sh $node:~/k8s_setup_node.sh
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "bash ~/k8s_setup_node.sh"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo bash ~/join-command.sh"
    ) &
done

wait

echo "All nodes have been added to the Kubernetes cluster"