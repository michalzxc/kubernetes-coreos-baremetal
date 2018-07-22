#!/bin/bash

while read -r line
do
  if [ ! -z "$(echo "$line")" ]; then
    ./build-cloud-config.sh $line
  fi
done < inventory/node-*/parameters
