#!/bin/bash

source ./config

# EXTERNAL_NET_CREATE="neutron net-create EXTERNAL_NET \
#    --router:external True \
#    --provider:network_type vlan \
#    --provider:physical_network physnet1 \
#    --provider:segmentation_id 304"
#
# EXTERNAL_SUBNET_CREATE="neutron subnet-create
#   --gateway 10.23.220.49 \
# 	--allocation-pool start=10.23.220.52,end=10.23.220.62 \
#   --dns-nameserver 172.29.74.154 \
#   --disable-dhcp \
#   --ip-version 4 \
#   --name ext_subnet \
#   EXTERNAL_NET 10.23.220.48/28"

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
  neutron router-gateway-set r${1} EXTERNAL_NET
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
