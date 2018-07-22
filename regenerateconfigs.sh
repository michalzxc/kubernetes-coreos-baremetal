#!/bin/bash

parameters="$(cat inventory/node-*/parameters)"

while read -r line
do
  if [ ! -z "$(echo "$line")" ]; then
    ./build-cloud-config.sh $line
  fi
done < <(echo -e "$parameters")

./updatemasters.sh
