#!/bin/bash

if [ ! -f inventory/masters ]; then
  echo "Generate masters first"
  exit
fi

masters=$(cat inventory/masters|awk -F'=' '{print $1}')

ALLENDPOINTS="$(cat inventory/masters|egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"|sed "s/^/http:\\/\\//g"|sed "s/$/:2379/g"|xargs|sed 's/ /,/g')"
if [ -z "$(echo $ALLENDPOINTS)" ]; then
  ALLENDPOINTS="$(cat inventory/masters|awk -F'=' '{print $2}'|sed "s/:2380/:2379,/g"|xargs|sed 's/,$//g'|sed 's/ //g')"
fi

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
  echo ${ALLENDPOINTS}
  sed -i "s#%ETCD_INITIAL_CLUSTER%#${ms}#g" inventory/node-${HOST}/cloud-config/openstack/latest/user_data
  sed -i "s#%ETCD_CALICO%#${ALLENDPOINTS}#g" inventory/node-${HOST}/cloud-config/openstack/latest/user_data
  ./build-image.sh inventory/node-${HOST}
done
