#!/bin/bash

export USER="michal"
export HOST="145.239.253.207"
export IMAGE="coreos_production_qemu_image.img"
export NETWORK="internal"
export CONTROLLERSIZE="15G"
export WORKERSIZE="50G"
export CONTROLLERMEMORY="8192"
export WORKERMEMORY="16384"

#---
export VIRSH_CONNECTION="qemu+ssh://$USER@$HOST/system"
export VMS="$(cat inventory/node-*/parameters|awk '{print $1}')"
function virshexec {
  virsh -c ${VIRSH_CONNECTION} $@
}

function sshexec {
  COMMAND="$(echo "$@"|base64 -w0)"
  ssh ${USER}@${HOST} "echo $password|sudo -S $(echo ${COMMAND}|base64 -d)" < /dev/null
}
#---

if [ ! -f tmp/sudopassword ]; then
  echo "Enter sudo password:"
  read sudopassword
  echo "${sudopassword}" > tmp/sudopassword
fi

password="$(cat tmp/sudopassword)"

#echo "Pull new version"
#git pull

#echo "[START] Regenerate config"
#./regenerateconfigs.sh
#echo "[END] Regenerate config"

export RUNNING="$(virshexec list --all|grep -v "Name"|awk '{print $2}')"
echo "Refresh Volumes"
virshexec pool-refresh  default
export VOLUMES="$(virshexec vol-list default|egrep -v "Name|----"|awk '{print $1}'|grep -v "^$")"
while read -r VM
do
  t="$(echo "${RUNNING}"|grep "^$VM$")"
  if [ $? -eq 0 ]; then
    echo "Found VM $VM, deleting"
    virshexec destroy $VM
    virshexec undefine $VM
  fi

  t="$(echo "${VOLUMES}"|grep "^$VM.img$")"
  if [ $? -eq 0 ]; then
    echo "Found Vol $VM.img, deleting"
    virshexec vol-delete --pool default $VM.img
  fi

  t="$(echo "${VOLUMES}"|grep "^node-$VM.iso$")"
  if [ $? -eq 0 ]; then
    echo "Found Vol node-$VM.iso, deleting"
    virshexec vol-delete --pool default node-$VM.iso
  fi

  echo "Create new storage"
  if [ ! -z "$(echo "$VM")|grep controlle" ]; then
    SIZE=${CONTROLLERSIZE}
  else
    SIZE=${WORKERSIZE}
  fi
  virshexec vol-clone ${IMAGE} $VM.img --pool default
  virshexec vol-resize --pool default --vol $VM.img ${SIZE}

  echo "Upload node-$VM.iso"
  scp inventory/node-$VM/config.iso ${USER}@${HOST}:~/node-$VM.iso

  echo "Move node-$VM.iso to /var/lib/libvirt/images/ and chown"
  sshexec "mv ~/node-$VM.iso /var/lib/libvirt/images/node-$VM.iso"
  sshexec "chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/node-$VM.iso"

  echo "Refresh Volumes"
  virshexec pool-refresh  default

  echo "Create VM: ${VM}"
  if [ ! -z "$(echo "$VM")|grep controlle" ]; then
    MEMORY=${CONTROLLERMEMORY}
  else
    MEMORY=${WORKERMEMORY}
  fi
  virt-install --connect ${VIRSH_CONNECTION} -n ${VM} --memory ${MEMORY} --virt-type=kvm --cpu=kvm64 --vcpus=2 --disk /var/lib/libvirt/images/$VM.img --network network=${NETWORK} --os-type=linux --os-variant=rhel7 --noreboot --noautoconsole --cdrom /var/lib/libvirt/images/node-$VM.iso
done < <(echo -e "$VMS")
