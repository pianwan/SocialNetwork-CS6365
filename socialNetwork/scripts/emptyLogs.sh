#!/bin/bash

echo -e "\e[33mremove previous logs of each container\e[0m"

for i in "node-0" "node-1" "node-2" "node-3" "node-4" "node-5"
do
	ssh $i '
	hostname
	sudo rm -rf /var/log/pods/
	'
done