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

# setup Registry
sudo mkdir -p /etc/containerd/certs.d/localhost:5000
echo "server = "http://localhost:5000"" | sudo tee /etc/containerd/certs.d/localhost:5000/hosts.toml
ctr -n k8s.io images pull docker.io/library/registry:2
sudo ctr -n k8s.io run --net-host --detach docker.io/library/registry:2 registry
sudo systemctl restart containerd

for i in $(seq 0 $NUM_NODES); do
    node="node-$i"
    echo "Connecting to $node..."
    (
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo mkdir -p /etc/containerd/certs.d/node-0:5000"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "echo "server = "http://node-0:5000"" | sudo tee /etc/containerd/certs.d/node-0:5000/hosts.toml"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo containerd config default | sudo tee /etc/containerd/config.toml"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "echo -e 'server = \"http://node-0:5000\"\n[host.\"http://node-0:5000\"]\n  capabilities = [\"pull\", \"resolve\"]' | sudo tee /etc/containerd/certs.d/node-0:5000/hosts.toml"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo sed -i '/registry.mirrors/a\ \ \ \ [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"node-0:5000\"]\n\ \ \ \ \ \ endpoint = [\"http://node-0:5000\"]' /etc/containerd/config.toml"
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node "sudo systemctl restart containerd && sudo systemctl restart kubelet"
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

buildctl build \
  --frontend=dockerfile.v0 \
  --local context=~/DeathStarBench/socialNetwork \
  --local dockerfile=~/DeathStarBench/socialNetwork \
  --output type=image,name=localhost:5000/social-network-microservices:withLog_01,push=true

buildctl build \
  --frontend=dockerfile.v0 \
  --local context=~/internal_triggers/cpu \
  --local dockerfile=~/internal_triggers/cpu \
  --output type=image,name=localhost:5000/cpu_intensive,push=true

buildctl build \
  --frontend=dockerfile.v0 \
  --local context=~/internal_triggers/io \
  --local dockerfile=~/internal_triggers/io \
  --output type=image,name=localhost:5000/io_intensive,push=true

buildctl build \
  --frontend=dockerfile.v0 \
  --local context=~/SetupScripts/socialNetwork/nginx_server \
  --local dockerfile=~/SetupScripts/socialNetwork/nginx_server \
  --output type=image,name=localhost:5000/nginx-web-server:v1,push=true

echo "** socialNetwork docker image build **"
