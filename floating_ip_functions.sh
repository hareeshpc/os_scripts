source ./devstack_functions_common

SLEEP_TIME=5
RETRY_ATTEMPTS=36
FIP_ARRAY=()

CREATE_FLOATING_IP(){
  # Arguments: external_net_name
  external_net=$1
  fip_id=$(neutron floatingip-create ${external_net} | egrep -w "id" | cut -d "|" -f 3)
  fip_ip=$(neutron floatingip-show ${fip_id} | egrep -w "floating_ip_address" | cut -d "|" -f 3)
  echo "Created floating ip ${fip_id} with IP address:${fip_ip}"
}


ASSOCIATE_FLOATING_IP_SUBNET(){
  # Arguments: subnet_name
  subnet_name=$1
  subnet_id=$(neutron subnet-show ${subnet_name} | egrep -w "id" | cut -d "|"  -f 3)
  dhcp_id=$(openstack port list --device-owner="network:dhcp" | egrep -w ${subnet_id} | head -n 1 | cut -d "|" -f 2)
  echo "dhcp id is:${dhcp_id}"
  echo "fip_id is: ${fip_id}"
  neutron floatingip-associate ${fip_id} ${dhcp_id}
  echo "+--------------------------------------+---------------------+------------------+--------------------------------------+"
  echo "| ID                                   | Floating IP Address | Fixed IP Address | Port                                 |"
  echo "+--------------------------------------+---------------------+------------------+--------------------------------------+"
  openstack floating ip list | egrep -w ${fip_id}
  echo "+--------------------------------------+---------------------+------------------+--------------------------------------+"
  FIP_ARRAY+=(${fip_ip})
}

ASSOCIATE_FLOATING_IP_WITH_VM(){
  # Args: vm_name floatingip_address
  local vm_name=$1
  local fip_ip=$2
  openstack server add floating ip ${vm_name} ${fip_ip}
  echo "+--------------------------------------+---------------------+------------------+--------------------------------------+"
  echo "| ID                                   | Floating IP Address | Fixed IP Address | Port                                 |"
  echo "+--------------------------------------+---------------------+------------------+--------------------------------------+"
  openstack floating ip list | egrep -w ${fip_ip}
  echo "+--------------------------------------+---------------------+------------------+--------------------------------------+"
  FIP_ARRAY+=(${fip_ip})
}


LIST_FLOATING_IP(){
  openstack floating ip list
}

DEBUG_ARRAY(){
  # Arguments: array name
  # Usage: DEBUG_ARRAY array_name[@]
  declare -a my_array=("${!1}")
  echo "Array size: ${#my_array[*]}"

  echo "Array items:"
  for item in ${my_array[*]}
  do
      printf "   %s\n" $item
  done
}

PING_SERVER(){
  echo "===== Ping floating IPs====="
  local local_array=("${!1}")
  START=1
  for c in $(eval echo "{$START..$RETRY_ATTEMPTS}"); do
    echo "Attempt:${c}/${RETRY_ATTEMPTS}"
    if [ ${#local_array[*]} -lt 1 ]; then
      echo "Nothing more to ping."
      break
    else
      for i in "${!local_array[@]}"; do
          ping -q -c 5 -W 1 -i 0.2 "${local_array[$i]}" > /dev/null 2>&1
          #and then check the response...
          if [ $? -eq 0 ]; then
            echo "Ping success. Removing ${local_array[$i]}"
            unset -v local_array[$i]
          else
            echo "Ping failed. Retaining ${local_array[$i]}"
          fi
      done
    fi
    if [ ${#local_array[*]} -gt 0 ]; then
      echo "Sleeping for ${SLEEP_TIME} seconds"
      sleep ${SLEEP_TIME}
    fi
  done
  if [ ${#local_array[*]} -gt 0 ]; then
    #DEBUG_ARRAY local_array[@]
    PRINT_PING_SERVER FIP_ARRAY[@]
    die $LINENO "One or more FloatingIPs failed to ping"
  fi
}

PRINT_PING_SERVER(){
  # Args: Array of ip address
  # Prints a final status of all floating ips
  declare -a ping_array=("${!1}")
  echo ""
  echo "+--------PING SUMMARY-------+--------+"
  echo "| IP                        | Status |"
  echo "+---------------------------+--------+"

  for ip in "${ping_array[@]}" ; do
    ping -q -c 5 -W 1 -i 0.2 ${ip} > /dev/null 2>&1
    #and then check the response...
    if [ $? -eq 0 ]
    then
      echo "${ip}                |   UP   |"
    else
      echo "${ip}                |  DOWN  |"
    fi
  done
  echo "+---------------------------+--------+"
}

DISASSOCIATE_FLOATING_IP(){
  # Arguments: floatingip-id
  fip_id=$1
}

DELETE_FLOATING_IP(){
  # Arguments: floatingip-id
  fip_id=$1
  echo -n "Processing to delete floating ip: ${fip_id}.. "
  neutron floatingip-delete ${fip_id}
  openstack floating ip list | egrep -w ${fip_id}
}

DELETE_ALL_FLOATING_IP(){
  for flid in $(openstack floating ip list | grep '^| [0-9a-f]' | cut -d "|" -f2)
  do
      DELETE_FLOATING_IP ${flid}
  done
}

# Main function for testing
#die $LINENO "This is a test message"
TEST_FLOATINGIP(){
START=1
END=3
for i in $(eval echo {${START}..${END}})
do
  CREATE_FLOATING_IP EXTERNAL_NET
  ASSOCIATE_FLOATING_IP_SUBNET subnet$i
done
PING_SERVER FIP_ARRAY[@]
PRINT_PING_SERVER FIP_ARRAY[@]
DELETE_ALL_FLOATING_IP
}
