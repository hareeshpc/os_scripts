#!/bin/bash
source ./logger.sh
source ~/openstack-configs/openrc
source ./net_sub_router_gw_functions.sh
source ./floating_ip_functions.sh
source ./nova_functions.sh

FUNC_USAGE() {
    INFO "Usage: $0 L3VM| L3 <start> <end> OR $0 CLEAN"
}

SILENT="1> /dev/null"
NETMASK="24"

CLEAN_ALL(){
  DEBUG ""
  DEBUG "===========Cleaning up============="
  DEBUG "[Cleaning Floating IPs]"
  DELETE_ALL_FLOATING_IP
  DEBUG "[Cleaning VMs]"
  CLEAN_ALL_VMS
  DEBUG "[Cleaning Routers]"
  FUNC_CLEAN_ROUTERS
  DEBUG "[Cleaning Networks]"
  FUNC_CLEAN_NETS_EXCLUDE_EXTERNAL
}

CLEAN_ALL_VMS(){
  DELETE_ALL_VMS
  CLEAN_VM_POSTREQ
}

TEST_L3VM(){
  local startindex=$1
  local endindex=$2
  # echo "Creating external network.."
  # eval $EXTERNAL_NET_CREATE
  # echo "Creating external subnet...."
  # eval $EXTERNAL_SUBNET_CREATE
  FUNC_FIND_EXTERNAL_NET
  for i in $(eval echo {${startindex}..${endindex}});
  do
    FUNC_NET_CREATE $i
    FUNC_SUBNET_CREATE $i

    FUNC_ROUTER_CREATE $i
    FUNC_ROUTER_INTERFACE_ADD $i
    FUNC_ROUTER_GATEWAY_SET $i
    local vm_name=test_vm$i
    CREATE_VM_PREREQ
    VM_CREATE net$i ${vm_name}
    CREATE_FLOATING_IP ${EXTERNAL_NET}
    ASSOCIATE_FLOATING_IP_WITH_VM ${vm_name} ${fip_ip}
  done

  LIST_FLOATING_IP
  # Test floating ip
  PING_SERVER FIP_ARRAY[@]
  PRINT_PING_SERVER FIP_ARRAY[@]

  CLEAN_ALL
}

TEST_L3(){
local startindex=$1
local endindex=$2
# eval $EXTERNAL_NET_CREATE
# eval $EXTERNAL_SUBNET_CREATE
FUNC_FIND_EXTERNAL_NET

for i in $(eval echo {${startindex}..${endindex}});
do
  FUNC_NET_CREATE $i
  FUNC_SUBNET_CREATE $i

  FUNC_ROUTER_CREATE $i
  FUNC_ROUTER_INTERFACE_ADD $i
  FUNC_ROUTER_GATEWAY_SET $i

  # Floating ip stuff
  CREATE_FLOATING_IP ${EXTERNAL_NET_ID}
  ASSOCIATE_FLOATING_IP_SUBNET subnet$i
done

LIST_FLOATING_IP

# Test floating ip
PING_SERVER FIP_ARRAY[@]
PRINT_PING_SERVER FIP_ARRAY[@]


echo " "
echo "=============CLEANING UP============"
DELETE_ALL_FLOATING_IP
FUNC_CLEAN_ROUTERS
FUNC_CLEAN_NETS_EXCLUDE_EXTERNAL
}

if [ $# -eq 3 ]
then
    CMD=$1
    START=$2
    END=$3
    if [ "$CMD" = "L3VM" ]; then
      TEST_L3VM $START $END
    elif [ "$CMD" = "L3" ]; then
      TEST_L3 $START $END
    fi
elif [ "$1" = "CLEAN" ]; then
  CLEAN_ALL
else
    FUNC_USAGE
    exit 1
fi
