#!/bin/bash

if [ ! -f inventory/masters ]; then
  echo "Generate masters first"
  exit
fi

masters=$(cat inventory/masters|awk -F'=' '{print $1}')

ms=""
for m in $(cat inventory/masters); do
  if [ ! -z "$ms" ]; then
    ms="$ms,$m"
  else
    ms="$m"
  fi
done

for HOST in $masters; do
  echo $ms
  sed -i "s#%ETCD_INITIAL_CLUSTER%#${ms}#g" inventory/node-${HOST}/cloud-config/openstack/latest/user_data
  ./build-image.sh inventory/node-${HOST}
done
