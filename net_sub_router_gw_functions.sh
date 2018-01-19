#!/bin/bash

source ./config

FUNC_FIND_EXTERNAL_NET(){
  echo "Finding suitable external network...."
  res=$(neutron net-list -c id -c name -c router:external | grep '| [0-9a-f]' | grep True | cut -d "|" -f 2| wc -l)
  if [ $res -gt 0 ]; then
    EXTERNAL_NET_ID=$(neutron net-list -c id -c name -c router:external | grep '| [0-9a-f]' | grep True | cut -d "|" -f 2)
    EXTERNAL_NET=$(neutron net-list -c name -c id  -c router:external | grep '| [0-9a-f]' | grep True | cut -d "|" -f 2)
    echo "Network: ${EXTERNAL_NET_ID} with name: ${EXTERNAL_NET} is an external network"
  else
    echo "No external network found"
  fi
}

FUNC_NET_CREATE(){
  local cmd="neutron net-create net${i} ${SILENT}"
  eval $cmd
  echo "Created network net${i}"
}

FUNC_SUBNET_CREATE(){
  local cmd="neutron subnet-create --name subnet${i} net${i} 192.168.${i}.0/${NETMASK} ${SILENT}"
  eval $cmd
  echo "Created subnet subnet${i}"
}

FUNC_ROUTER_CREATE(){
  local cmd="neutron router-create r${1} ${SILENT}"
  eval $cmd
  echo "Created router r${i}"
}

FUNC_ROUTER_INTERFACE_ADD(){
  neutron router-interface-add r${1} subnet${1}
}

FUNC_ROUTER_GATEWAY_SET(){
  neutron router-gateway-set r${1} ${EXTERNAL_NET_ID}
}

FUNC_CLEAN_ROUTERS(){
# Get list of routers
for router in $(neutron router-list | grep '^| [0-9a-f]' | cut -d "|" -f 3)
do
  rid=$(echo $router | tr -dc '0-9')
  echo "Processing router:${router} with subnet: subnet${rid}"
  neutron router-interface-delete $router subnet${rid}
  neutron router-gateway-clear $router
  neutron router-delete $router
done
}

FUNC_CLEAN_NETS(){
for net in $(neutron net-list | grep '^| [0-9a-f]' | cut -d "|" -f2)
do
    neutron net-delete $net
done
}

FUNC_CLEAN_NETS_EXCLUDE_EXTERNAL(){
for net in $(neutron net-list -c id -c name -c router:external | grep '| [0-9a-f]' | grep -v True | cut -d "|" -f 2)
do
  neutron net-delete $net
done
}
