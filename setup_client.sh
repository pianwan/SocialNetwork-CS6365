#!/bin/bash
# deploy client
NUM_NODES=${1:-11}


ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa node-6 "sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sysdig maven pdfgrep"

for i in $(seq 6 $NUM_NODES); do
    node="node-$i"
    echo "Connecting to $node..."
    # put key
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ~/.ssh/id_rsa $node:~/.ssh/id_rsa
    # put Rubbos and DeathBench
    ssh-keygen -F github.com || ssh-keyscan github.com >> ~/.ssh/known_hosts && git clone https://github.com/delimitrou/DeathStarBench.git ~/DeathStarBench && cd ~/DeathStarBench && git checkout b2b7af9 && cd ~
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ~/RubbosClient.zip $node:~/RubbosClient.zip
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ~/src.zip $node:~/src.zip
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ~/socialNetwork.zip $node:~/socialNetwork.zip
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ~/scripts_limit.zip $node:~/scripts_limit.zip
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ~/internal_triggers.zip $node:~/internal_triggers.zip
    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ~/RubbosClient_src.zip $node:~/RubbosClient_src.zip

    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node 'if [ ! -e "$HOME/.ssh/config" ]; then echo -e "Host *\n\tStrictHostKeyChecking no" >> "$HOME/.ssh/config"; fi'
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa $node 'unzip RubbosClient.zip
                                                            mv RubbosClient/elba .
                                                            mv RubbosClient/rubbos .
                                                            gcc $HOME/elba/rubbos/RUBBoS/bench/flush_cache.c -o $HOME/elba/rubbos/RUBBoS/bench/flush_cache'
    echo "** RubbosClient copied **"

done

cd ~
unzip -o src.zip
unzip -o RubbosClient_src.zip
unzip -o socialNetwork.zip
unzip -o scripts_limit.zip
unzip -o internal_triggers.zip
mv DeathStarBench/socialNetwork/src DeathStarBench/socialNetwork/src.bk
mv src DeathStarBench/socialNetwork/
mv socialNetwork/* DeathStarBench/socialNetwork/
mv socialNetwork/scripts/*.sh DeathStarBench/socialNetwork/scripts/
rm -r socialNetwork/scripts
cd ~/DeathStarBench/socialNetwork
echo "** socialNetwork stack deployed **"

cd ~/RubbosClient_src
mvn clean
mvn package
./cpToCloud.sh
echo "** client binary distributed **"

cd ~/DeathStarBench/wrk2
make
sudo apt-get -y install libssl-dev libz-dev luarocks
sudo luarocks install luasocket
cd ~/DeathStarBench/socialNetwork
# port forward
sudo apt-get install socat -y

nohup kubectl port-forward svc/nginx-web-server 8090:8080 -n social-network > port-forward-nginx.log 2>&1 &
nohup kubectl port-forward svc/media-frontend 8091:8081 -n social-network > port-forward-media.log 2>&1 &
sudo socat TCP-LISTEN:8080,fork TCP:127.0.0.1:8090 &
sudo socat TCP-LISTEN:8081,fork TCP:127.0.0.1:8091 &

./start.sh register
./start.sh compose
echo "** socialNetwork data created **"

echo "core dedicated **\n** all the work is done, begin running the experiment **"