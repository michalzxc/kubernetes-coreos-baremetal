#!/bin/bash

# help view
if [ "$#" != "2" ] && [ "$#" != "3" ]; then
	echo "usage: ./build-cloud-config.sh HOSTNAME/PREFIX IP [MASTER_GW]"
	exit 1
fi

# setting vars from args
HOST=$1
IP=$(echo "$2"| cut -d'/' -f1)
ETCDADVERTISEIP=${IP}
PREFIX=$(echo "$2"| cut -d'/' -f2)

mkdir -p inventory/node-${HOST}/ssl
echo "creating SSL keys"

# check if certificate authority exists
if [ ! -f ssl/ca.pem ]; then
  mkdir ssl/
	# create certificate authority
	openssl genrsa -out ssl/ca-key.pem 2048
 	openssl req -x509 -new -nodes -key ssl/ca-key.pem -days 10000 -out ssl/ca.pem -subj "/CN=kube-ca"

	# create administrator keypair
	openssl genrsa -out ssl/admin-key.pem 2048
	openssl req -new -key ssl/admin-key.pem -out ssl/admin.csr -subj "/CN=kube-admin"
	openssl x509 -req -in ssl/admin.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out ssl/admin.pem -days 3650
fi

if [ ! -z "$(echo "$1"|grep "controller")" ]; then
	# configure master
	ADVERTISE_IP=${IP}
	HOSTIP=${IP}
	if [ ! -f inventory/gw ]; then
		GW=$3
		echo $GW>inventory/gw
		openssl genrsa -out ssl/accounts-key.pem 2048
		if [ ! -z "$(echo "$IP"|egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")" ]; then
			IP=${IP} openssl req -new -key ssl/accounts-key.pem -out ssl/accounts-key.csr -subj "/CN=kube-apiserver" -config master-openssl.cnf
			IP=${IP} openssl x509 -req -in ssl/accounts-key.csr  -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out ssl/accounts.pem -days 3650 -extensions v3_req -extfile master-openssl.cnf
		else
			CNAME=${IP} openssl req -new -key ssl/accounts-key.pem -out ssl/accounts-key.csr -subj "/CN=kube-apiserver" -config master-opensslcname.cnf
			CNAME=${IP} openssl x509 -req -in ssl/accounts-key.csr  -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out ssl/accounts.pem -days 3650 -extensions v3_req -extfile master-opensslcname.cnf
		fi
	fi
		ETCD_INITIAL_CLUSTER_STATE=new
	echo "$1=http://${HOSTIP}:2380">>inventory/masters
	NODETYPE="apiserver"
	INSTALLURL=kubeinstall/controller-install.sh
	NOETCDCLUSTER=0

	openssl genrsa -out inventory/node-${HOST}/ssl/apiserver-key.pem 2048
	if [ ! -z "$(echo "$IP"|egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")" ]; then
		IP=${IP} openssl req -new -key inventory/node-${HOST}/ssl/apiserver-key.pem -out inventory/node-${HOST}/ssl/apiserver.csr -subj "/CN=kube-apiserver" -config master-openssl.cnf
		IP=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/apiserver.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/apiserver.pem -days 3650 -extensions v3_req -extfile master-openssl.cnf
	else
		CNAME=${IP} openssl req -new -key inventory/node-${HOST}/ssl/apiserver-key.pem -out inventory/node-${HOST}/ssl/apiserver.csr -subj "/CN=kube-apiserver" -config master-opensslcname.cnf
		CNAME=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/apiserver.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/apiserver.pem -days 3650 -extensions v3_req -extfile master-opensslcname.cnf
	fi
	echo "$HOSTIP/$PREFIX" > inventory/node-${HOST}/ip
	echo "creating CoreOS cloud-config for controller ${HOST}(${IP})"
	ENDPOINTS="http://${IP}:2379"
else
	# configure worker
	ADVERTISE_IP=${IP}
	MASTER=$3
	HOSTIP=${IP}
	NODETYPE="worker"
	INSTALLURL=kubeinstall/worker-install.sh
	NOETCDCLUSTER=1

	openssl genrsa -out inventory/node-${HOST}/ssl/worker-key.pem 2048
	if [ ! -z "$(echo "$IP"|egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")" ]; then
		WORKER_IP=${IP} openssl req -new -key inventory/node-${HOST}/ssl/worker-key.pem -out inventory/node-${HOST}/ssl/worker.csr -subj "/CN=${HOST}" -config worker-openssl.cnf
		WORKER_IP=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/worker.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/worker.pem -days 3650 -extensions v3_req -extfile worker-openssl.cnf
	else
		WORKER_CNAME=${IP} openssl req -new -key inventory/node-${HOST}/ssl/worker-key.pem -out inventory/node-${HOST}/ssl/worker.csr -subj "/CN=${HOST}" -config worker-opensslcname.cnf
		WORKER_CNAME=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/worker.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/worker.pem -days 3650 -extensions v3_req -extfile worker-opensslcname.cnf
	fi
	echo "$HOSTIP/$PREFIX" > inventory/node-${HOST}/ip
	echo "creating CoreOS cloud-config for $HOST with K8S version $K8S_VER to join $MASTER"
	IP=${MASTER} # for etcd2 config

	ENDPOINTS="$(cat inventory/masters|awk -F'//' '{print $2}'|awk -F':' '{print $1}'|sed "s/^/http:\\/\\//g"|sed "s/$/:2379/g"|xargs|sed 's/ /,/g')"
	echo "ENDPOINTS: $ENDPOINTS"
fi

HAPROXYAPI="$(cat inventory/masters|egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"|awk '{print $1":443"}'|xargs)"
if [ -z "$(echo $HAPROXYAPI)" ]; then
	HAPROXYAPI="$(cat inventory/masters|awk -F'=' '{print $2}'|sed 's/http:\/\///g'|awk -F':' '{print $1":443"}'|xargs)"
fi

# create cloud config folder
rm -f inventory/node-${HOST}/install.sh
mkdir -p inventory/node-${HOST}/cloud-config/openstack/latest
cp  ${INSTALLURL} inventory/node-${HOST}/install.sh
cat inventory/node-${HOST}/install.sh | \
sed -e "s% ETCD_ENDPOINTS=% ETCD_ENDPOINTS=${ENDPOINTS}%" | \
sed -e "s/%HAPROXYAPI%/${HAPROXYAPI}/g" | \
sed -e "s/CONTROLLER_ENDPOINT=/CONTROLLER_ENDPOINT=http:\/\/127.0.0.1:8182/g" > inventory/node-${HOST}/installtmp.sh
mv inventory/node-${HOST}/installtmp.sh inventory/node-${HOST}/install.sh

GW="$(cat inventory/gw)"
if [ -z "$(echo "$GW"| grep "dhcp")" ]; then
netconf=$(cat << EOF
- name: 00-%HOST%.network
  content: |
    [Match]
    Name=eth0
    [Network]
    Address=%HOSTIP%/%PREFIX%
    Gateway=%GW%
    DNS=8.8.8.8
EOF
)
else
netconf=$(cat << EOF
- name: 00-%HOST%.network
  content: |
    [Match]
    Name=eth0
    [Network]
    DHCP=yes
    DNS=8.8.8.8
EOF
)
fi
netconf=$(echo "$netconf"|sed -e 's/\(.*\)/    \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')
cat certonly-tpl.yaml | sed -e "s/%NETSECTION%/$netconf/g" >  certonly-tpl.yaml2
###OpenStack DNS
if [ -f cloudconf-openstack ]; then
netenv="$(cat cloudconf-openstack)"
cloudconf=$(cat << EOF
- name: openstackhosts.service
  content: |
    [Unit]
    Description=OpenStack Hostsfile Updated
    [Service]
    Type=simple
    ExecStart=/usr/bin/rkt --insecure-options=all run %NETENV% --volume hosts,kind=host,source=/etc/hosts,readOnly=false --mount volume=hosts,target=/etc/hosts --volume dns,kind=host,source=/etc/resolv.conf --mount volume=dns,target=/etc/resolv.conf --uuid-file-save=/var/run/openstackhosts.uuid docker://michalzxc/openstackhosts:latest --caps-retain="CAP_SYS_ADMIN,CAP_DAC_READ_SEARCH,CAP_CHOWN" --exec /usr/local/sbin/hostsupdate
    [Install]
    WantedBy=multi-user.target
- name: openstackhosts.timer
  command: start
  enable: true
  content: |
    [Unit]
    Description=OpenStack Hostsfile Updated
    [Timer]
    Unit=openstackhosts.service
    OnCalendar=*:0/1
    [Install]
    WantedBy=timers.target
EOF
)
	cloudconf="$(echo -e "$cloudconf"|sed -e "s@%NETENV%@$netenv@g")"
	cloudconf=$(echo "$cloudconf"|sed -e 's/\(.*\)/    \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')
else
	cloudconf=""
fi
cat certonly-tpl.yaml2 | sed -e "s/%CLOUDSECTION%/$cloudconf/g" >  certonly-tpl.yaml3

# bash templating
rm -f inventory/node-${HOST}/cloud-config/openstack/latest/user_data
cat certonly-tpl.yaml3 | \
sed -e s/%HOST%/${HOST}/g | \
sed -e "s/%INSTALL_SCRIPT%/$(<inventory/node-${HOST}/install.sh sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e "s/%CA_PEM%/$(<ssl/ca.pem sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e "s/%NODE_PEM%/$(<inventory/node-${HOST}/ssl/${NODETYPE}.pem sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e "s/%NODE_KEY_PEM%/$(<inventory/node-${HOST}/ssl/${NODETYPE}-key.pem sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e "s/%ACCOUNTS_PEM%/$(<ssl/accounts.pem sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e "s/%ACCOUNTS_KEY_PEM%/$(<ssl/accounts-key.pem sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e s/%NODETYPE%/${NODETYPE}/g | \
sed -e s/%ADVERTISE_IP%/${ADVERTISE_IP}/g | \
sed -e s/%IP%/${IP}/g | \
sed -e s/%ETCDADVERTISEIP%/${ETCDADVERTISEIP}/g | \
sed -e s/%PREFIX%/${PREFIX}/g | \
sed -e s/%FIRSTMASTER%/${FIRSTMASTER}/g | \
sed -e s/%GW%/${GW}/g | \
sed -e s/%ETCD_INITIAL_CLUSTER_STATE%/${ETCD_INITIAL_CLUSTER_STATE}/g | \
sed -e s/%HOSTIP%/${HOSTIP}/g > inventory/node-${HOST}/cloud-config/openstack/latest/user_data

if [ $NOETCDCLUSTER -eq 1 ]; then
	cat inventory/node-${HOST}/cloud-config/openstack/latest/user_data | \
	 grep -v "ETCD_INITIAL_CLUSTER_STATE" | \
	 grep -v "ETCD_LISTEN_PEER_URLS" | \
	 grep -v "ETCD_INITIAL_CLUSTER" | \
	 grep -v "ETCD_INITIAL_ADVERTISE_PEER_URLS" > inventory/node-${HOST}/cloud-config/openstack/latest/user_data_new
	 mv inventory/node-${HOST}/cloud-config/openstack/latest/user_data_new inventory/node-${HOST}/cloud-config/openstack/latest/user_data
fi

./build-image.sh inventory/node-${HOST}
