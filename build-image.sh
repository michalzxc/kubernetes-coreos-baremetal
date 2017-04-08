#!/bin/bash

DIR=$1
genisoimage -R -V config-2 -o ${DIR}/config.iso ${DIR}/cloud-config
