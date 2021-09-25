#!/bin/bash

## What to change?
# - The "environment" variables
# - Library dependencies (Here, just bc)
# - Compilation command (Here, ./Allwmake)

## Dependencies
NET_NAME="foam-extend-41-openmpi_net"
LIB_TAR_URL=https://transfer.sh/FX8Yu2/amr.tar
CASE_URL=https://transfer.sh/uAA7so/threeD.tar
SLAVES_NUM=3

if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Get it and re-run please"
    exit
fi
if ! command -v docker &> /dev/null
then
    echo "docker could not be found. Get it and re-run please"
    exit
fi
if ! command -v docker-compose &> /dev/null
then
    echo "docker-compose could not be found. Get it and re-run please"
    exit
fi


slaves=()
for i in $(seq 1 $SLAVES_NUM); do slaves+=('--index='$i' slave'); done

##### 0. Fire up the cluster
docker-compose up -d --scale master=1 --scale slave=$SLAVES_NUM
sleep 3

##### 1. First things first; MPI doesn't like underscores in names, so:
# Get all IPs in the network, with container names, and replace _ with -
docker network inspect "$NET_NAME" \
    | jq -r '.[].Containers[] | .IPv4Address + " " + .Name' \
    | tr '_' '-' | sed 's_/16__' > d_hosts
# Add this hosts configuration to all containers
for node in master "${slaves[@]}";
    do 
    docker-compose exec -T $node sudo bash -ic "echo \"`cat d_hosts`\" >> /etc/hosts"
done

##### 2. Compile a library, and run a case

# Copy the library TAR and unpack in /data from master node
docker-compose exec master curl "$LIB_TAR_URL" -o lib.tar
docker-compose exec master tar -xvf lib.tar

# Install library dependencies in each node (In parallel, then wait for the processes to finish)
count=0
for node in master "${slaves[@]}";
    do 
    docker-compose exec -T $node bash -c 'sudo apt update; sudo apt install -y bc' &
    count+=1
    pids[${count}]=$!
done
for pid in ${pids[*]}; do
    wait $pid
done

# Start compiling on master and wait a little (for lnInclude to be generated)
docker-compose exec -T master bash -ic './Allwmake' &
mpid=$!
sleep 3

# Compile on slaves and wait for all compilation processes to finish
count=0
for node in "${slaves[@]}";
    do 
    docker-compose exec -T $node bash -ic './Allwmake' &
    count+=1
    pids[${count}]=$!
done
wait $mpid
for pid in ${pids[*]}; do
    wait $pid
done

# Make nodes aware of an environment variable
for node in master "${slaves[@]}";
    do 
    docker-compose exec -T $node bash -c "echo 'export LBAMR_PROJECT=/data' >> ~/.bashrc"
done

# Get the case
docker-compose exec -T master bash -c "curl $CASE_URL -o case.tar; tar -xvf case.tar"

echo ""
echo "OK."
