SILENT="1> /dev/null"
CIRROS_NAME="cirros-0.3.5"

DOWNLOAD_CIRROS(){
  echo "Downloading Cirros image if needed..."
  if [ ! -f cirros-0.3.5-x86_64-disk.img ]; then
    curl -O http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img 1> /dev/null
  fi
}

CREATE_KEYS(){
  if [ ! -f /root/.ssh/openstack.pub ]; then
    echo "Creating neccessary ssh keys [.ssh/openstack{.pub}]"
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/openstack -C openstack@mercury
  fi
}

NOVA_ADD_KEYS(){
  echo "Creating keypair openstack if needed.."
  local res=$( openstack keypair list | grep openstack | wc -l)
  if [ $res != 1 ]; then
    openstack keypair create --public-key ~/.ssh/openstack.pub openstack
  fi
}

NOVA_DEL_KEYS(){
  echo "Deleting keypair openstack if needed.."
  local res=$( openstack keypair list | grep openstack | wc -l)
  if [ $res == 1 ]; then
    openstack keypair delete openstack
  fi
}

CREATE_FLAVORS(){
  echo "Creating m1.tiny flavor if needed...."
  local res=$(openstack flavor list | grep '^| [0-9a-f]' | egrep -w "m1.tiny" | wc -l)
  if [ $res != 1 ]; then
    openstack flavor create --public m1.tiny --id auto --ram 1024 --disk 1 --vcpus 1 --rxtx-factor 1 --property hw:mem_page_size=large 1> /dev/null
  fi
  #openstack flavor list
}

CREATE_SEC_GROUP(){

  echo "Creating my_sec_group with icmp and ssh permissions if needed...."
  res=$(openstack security group list | grep -w "my_sec_group"| wc -l)
  if [ $res -lt 1 ]; then
    openstack security group create my_sec_group 1> /dev/null
    openstack security group rule create --proto icmp my_sec_group 1> /dev/null
    openstack security group rule create --proto tcp --dst-port 22 my_sec_group 1> /dev/null
  fi
}

UPLOAD_CIRROS(){
  echo "Uploading Cirros-0.3.5 image if needed...."
  res=$(openstack image list | egrep -w ${CIRROS_NAME} | wc -l)
  if [ $res != 1 ]; then
    openstack image create ${CIRROS_NAME} \
      --file cirros-0.3.5-x86_64-disk.img \
      --disk-format qcow2 --container-format bare \
      --public 1> /dev/null
  fi
}

WAIT_TILL_ACTIVE(){
  # Args: vm_name
  local vm_name=$1
  local START=1
  local RETRY_ATTEMPTS=12
  local SLEEP_TIME=5
  local status="UNKNOWN"
  for c in $(eval echo "{$START..$RETRY_ATTEMPTS}"); do
    sleep ${SLEEP_TIME}
    echo "Attempt:${c}/${RETRY_ATTEMPTS}. Status is ${status}"
    status=$(nova list | egrep ${instance_name} | grep '^| [0-9a-f]' | cut -d "|" -f 4)
    if [ ${status} = "ACTIVE" ]; then
      echo "VM ${vm_name} is now ${status}"
      break
    elif [ ${status} = "ERROR" ]; then
      reason=$(nova show ${vm_name} | egrep -w -A 10 "fault")
      die $LINENO "${vm_name} has gone to ${status} status. Reason: ${reason}"
    fi
  done
}

VM_CREATE(){
  # A cirros VM is created with the default sec group
  # Args: instance name
  # #--key-name mykey \
  net=$1
  instance_name=$2
  echo "Spawning instance:${instance_name}. This will take a few seconds to become active"
  openstack server create \
    --flavor m1.tiny --image cirros-0.3.5 \
    --nic net-id=${net} --security-group my_sec_group \
    ${instance_name} 1> /dev/null
    WAIT_TILL_ACTIVE ${instance_name}
}

DELETE_ALL_VMS(){
  # Arguments: VM name wild card, defaults to "test_vm"
  local vm_name=${1:-test_vm}
  for vm_id in $(nova list | egrep ${vm_name} | grep '^| [0-9a-f]' | cut -d "|" -f 2)
  do
    local vname=$(nova show ${vm_id} | egrep -w "name" | cut -d "|" -f 3 | xargs)
    echo -n "Proceeding to delete VM:${vname}.... "
    nova delete ${vm_id}
  done
}

CLEAN_VM_POSTREQ(){
  openstack image delete cirros-0.3.5
  for sec_id in $(openstack security group list | grep -w "my_sec_group" | cut -d "|" -f 2); do
    openstack security group delete ${sec_id}
  done

  openstack flavor delete m1.tiny
}

CLEAN_ALL(){
  DELETE_ALL_VMS
  CLEAN_VM_POSTREQ
}

CREATE_VM_PREREQ(){
  CREATE_FLAVORS
  DOWNLOAD_CIRROS
  UPLOAD_CIRROS
  CREATE_SEC_GROUP
}

TEST_VM(){
  CREATE_VM_PREREQ
  VM_CREATE net1 test_vm1
}

# if [ "$1" = "CLEAN" ]; then
#   CLEAN_ALL
# else
#   TEST_VM
# fi
