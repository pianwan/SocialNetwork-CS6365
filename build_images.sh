#!/bin/bash

NUM_NODES=${1:-6}

# setup buildkit
sudo apt install -y make gcc linux-libc-dev libseccomp-dev pkg-config git
wget https://github.com/moby/buildkit/releases/download/v0.20.1/buildkit-v0.20.1.linux-amd64.tar.gz
tar -xzf buildkit-v0.20.1.linux-amd64.tar.gz
sudo mv bin/* /usr/local/bin/
rm -rf buildkit-v0.20.1.linux-amd64.tar.gz
rm -rf bin

echo "** buildkit installed **"

for i in $(seq 0 $NUM_NODES); do
    node="node-$i"
    echo "Connecting to $node..."
    (
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo mkdir -p /etc/containerd/certs.d/localhost:5000"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "echo \"server = \"http://localhost:5000\"\" | sudo tee /etc/containerd/certs.d/localhost:5000/hosts.toml"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "curl -LO https://github.com/containerd/nerdctl/releases/download/v1.7.6/nerdctl-1.7.6-linux-amd64.tar.gz
                                                            tar -xzf nerdctl-1.7.6-linux-amd64.tar.gz
                                                            sudo mv nerdctl /usr/local/bin/"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo nerdctl run -d --name registry --restart=always --net=host registry:2"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo systemctl restart containerd"
    ) &
done

wait

echo "** All nodes have added registry **"

# clone origin repo
ssh-keygen -F github.com || ssh-keyscan github.com >> ~/.ssh/known_hosts && git clone https://github.com/delimitrou/DeathStarBench.git ~/DeathStarBench && cd ~/DeathStarBench && git checkout b2b7af9 && cd ~
# unzip
unzip '*.zip'
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt install -y sysdig
sudo DEBIAN_FRONTEND=noninteractive apt install -y collectl

mv ~/DeathStarBench/socialNetwork/src ~/DeathStarBench/socialNetwork/src.bk
mv ~/src ~/DeathStarBench/socialNetwork/
sudo buildkitd > /dev/null 2>&1 &
until [ -S /run/buildkit/buildkitd.sock ]; do
    sleep 1
done

echo "** Building images **"

buildctl build \
  --frontend=dockerfile.v0 \
  --local context=~/DeathStarBench/socialNetwork \
  --local dockerfile=~/DeathStarBench/socialNetwork \
  --output type=oci,dest=social-network-microservices.tar,name=social-network-microservices:withLog_01

buildctl build \
  --frontend=dockerfile.v0 \
  --local context=~/internal_triggers/cpu \
  --local dockerfile=~/internal_triggers/cpu \
  --output type=oci,dest=cpu_intensive.tar,name=cpu_intensive:v1

buildctl build \
  --frontend=dockerfile.v0 \
  --local context=~/internal_triggers/io \
  --local dockerfile=~/internal_triggers/io \
  --output type=oci,dest=io_intensive.tar,name=io_intensive:v1

buildctl build \
  --frontend=dockerfile.v0 \
  --local context=~/SetupScripts/socialNetwork/nginx_server \
  --local dockerfile=~/SetupScripts/socialNetwork/nginx_server \
  --output type=oci,dest=nginx-web-server.tar,name=nginx-web-server:v1

echo "** Pushing to worker nodes **"

sudo ctr -n=k8s.io images import social-network-microservices.tar
for i in $(seq 0 $NUM_NODES); do
    node="node-$i"
    echo "push social-network-microservices to $node..."
    sudo ctr -n=k8s.io images tag docker.io/library/social-network-microservices:withLog_01 $node:5000/social-network-microservices:withLog_01
    sudo ctr -n=k8s.io images push --plain-http $node:5000/social-network-microservices:withLog_01
done

sudo ctr -n=k8s.io images import cpu_intensive.tar
for i in $(seq 0 $NUM_NODES); do
    node="node-$i"
    echo "push cpu_intensive to $node..."
    sudo ctr -n=k8s.io images tag docker.io/library/cpu_intensive:v1 $node:5000/cpu_intensive
    sudo ctr -n=k8s.io images push --plain-http $node:5000/cpu_intensive
done

sudo ctr -n=k8s.io images import io_intensive.tar
for i in $(seq 0 $NUM_NODES); do
    node="node-$i"
    echo "push io_intensive to $node..."
    sudo ctr -n=k8s.io images tag docker.io/library/io_intensive:v1 $node:5000/io_intensive
    sudo ctr -n=k8s.io images push --plain-http $node:5000/io_intensive
done

sudo ctr -n=k8s.io images import nginx-web-server.tar
for i in $(seq 0 $NUM_NODES); do
    node="node-$i"
    echo "push nginx-web-server to $node..."
    sudo ctr -n=k8s.io images tag docker.io/library/nginx-web-server:v1 $node:5000/nginx-web-server:v1
    sudo ctr -n=k8s.io images push --plain-http $node:5000/nginx-web-server:v1
done

for i in $(seq 0 $NUM_NODES); do
    node="node-$i"
    echo "registry at $node"
    curl http://"$node":5000/v2/_catalog
done

echo "** Pushed to all worker nodes **"

echo "** socialNetwork image prepared successfully **"
