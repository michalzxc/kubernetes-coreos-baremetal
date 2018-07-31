#!/bin/bash

# help view
if [ "$#" != "2" ] && [ "$#" != "3" ]; then
	echo "usage: ./build-cloud-config.sh HOSTNAME/PREFIX IP [MASTER_GW]"
	exit 1
fi

mkdir -p tmp

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
		if [ ! -f ssl/accounts-key.pem ]; then
			openssl genrsa -out ssl/accounts-key.pem 2048
		fi
		if [ ! -z "$(echo "$IP"|egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")" ]; then
			if [ ! -f ssl/accounts-key.csr ]; then
				IP=${IP} openssl req -new -key ssl/accounts-key.pem -out ssl/accounts-key.csr -subj "/CN=kube-apiserver" -config master-openssl.cnf
			fi
			if [ ! -f ssl/accounts.pem ]; then
				IP=${IP} openssl x509 -req -in ssl/accounts-key.csr  -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out ssl/accounts.pem -days 3650 -extensions v3_req -extfile master-openssl.cnf
			fi
		else
			if [ ! -f ssl/accounts-key.csr ]; then
				CNAME=${IP} openssl req -new -key ssl/accounts-key.pem -out ssl/accounts-key.csr -subj "/CN=kube-apiserver" -config master-opensslcname.cnf
			fi
			if [ ! -f ssl/accounts.pem ]; then
				CNAME=${IP} openssl x509 -req -in ssl/accounts-key.csr  -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out ssl/accounts.pem -days 3650 -extensions v3_req -extfile master-opensslcname.cnf
			fi
		fi
	fi
		ETCD_INITIAL_CLUSTER_STATE=new
	echo "$1=https://${HOSTIP}:2380">>inventory/masters
	NODETYPE="apiserver"
	INSTALLURL=kubeinstall/controller-install.sh
	NOETCDCLUSTER=0

	if [ ! -f inventory/node-${HOST}/ssl/apiserver-key.pem ]; then
		openssl genrsa -out inventory/node-${HOST}/ssl/apiserver-key.pem 2048
	fi
	if [ ! -z "$(echo "$IP"|egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")" ]; then
		if [ ! -f inventory/node-${HOST}/ssl/apiserver.csr ]; then
			IP=${IP} openssl req -new -key inventory/node-${HOST}/ssl/apiserver-key.pem -out inventory/node-${HOST}/ssl/apiserver.csr -subj "/CN=kube-apiserver" -config master-openssl.cnf
		fi
		if [ ! -f inventory/node-${HOST}/ssl/apiserver.pem ]; then
			IP=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/apiserver.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/apiserver.pem -days 3650 -extensions v3_req -extfile master-openssl.cnf
		fi
	else
		if [ ! -f inventory/node-${HOST}/ssl/apiserver.csr ]; then
			CNAME=${IP} openssl req -new -key inventory/node-${HOST}/ssl/apiserver-key.pem -out inventory/node-${HOST}/ssl/apiserver.csr -subj "/CN=kube-apiserver" -config master-opensslcname.cnf
		fi
		if [ ! -f inventory/node-${HOST}/ssl/apiserver.pem ]; then
			CNAME=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/apiserver.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/apiserver.pem -days 3650 -extensions v3_req -extfile master-opensslcname.cnf
		fi
	fi
	echo "$HOSTIP/$PREFIX" > inventory/node-${HOST}/ip
	echo "creating CoreOS cloud-config for controller ${HOST}(${IP})"
	ENDPOINTS="https://${IP}:2379"
else
	# configure worker
	ADVERTISE_IP=${IP}
	MASTER=$3
	HOSTIP=${IP}
	NODETYPE="worker"
	INSTALLURL=kubeinstall/worker-install.sh
	NOETCDCLUSTER=1

	if [ ! -f inventory/node-${HOST}/ssl/worker-key.pem ]; then
		openssl genrsa -out inventory/node-${HOST}/ssl/worker-key.pem 2048
	fi
	if [ ! -z "$(echo "$IP"|egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")" ]; then
		if [ ! -f inventory/node-${HOST}/ssl/worker.csr ]; then
			WORKER_IP=${IP} openssl req -new -key inventory/node-${HOST}/ssl/worker-key.pem -out inventory/node-${HOST}/ssl/worker.csr -subj "/CN=${HOST}" -config worker-openssl.cnf
		fi
		if [ ! -f inventory/node-${HOST}/ssl/worker.pem ]; then
			WORKER_IP=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/worker.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/worker.pem -days 3650 -extensions v3_req -extfile worker-openssl.cnf
		fi
	else
		if [ ! -f inventory/node-${HOST}/ssl/worker.csr ]; then
			WORKER_CNAME=${IP} openssl req -new -key inventory/node-${HOST}/ssl/worker-key.pem -out inventory/node-${HOST}/ssl/worker.csr -subj "/CN=${HOST}" -config worker-opensslcname.cnf
		fi
		if [ ! -f inventory/node-${HOST}/ssl/worker.pem ]; then
			WORKER_CNAME=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/worker.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/worker.pem -days 3650 -extensions v3_req -extfile worker-opensslcname.cnf
		fi
	fi
	echo "$HOSTIP/$PREFIX" > inventory/node-${HOST}/ip
	echo "creating CoreOS cloud-config for $HOST with K8S version $K8S_VER to join $MASTER"
	IP=${MASTER} # for etcd2 config

	ENDPOINTS="$(cat inventory/masters|awk -F'//' '{print $2}'|awk -F':' '{print $1}'|sed "s/^/https:\\/\\//g"|sed "s/$/:2379/g"|xargs|sed 's/ /,/g')"
	echo "ENDPOINTS: $ENDPOINTS"
fi

HAPROXYAPI="$(cat inventory/masters|egrep -o "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"|awk '{print $1":443"}'|xargs)"
if [ -z "$(echo $HAPROXYAPI)" ]; then
	HAPROXYAPI="$(cat inventory/masters|awk -F'=' '{print $2}'|sed 's/https:\/\///g'|awk -F':' '{print $1":443"}'|xargs)"
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
EOF
)
fi
netconf=$(echo "$netconf"|sed -e 's/\(.*\)/    \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')
cat certonly-tpl.yaml | sed -e "s/%NETSECTION%/$netconf/g" >  tmp/certonly-tpl.yaml2a

if [ $NOETCDCLUSTER -eq 1 ]; then
	etcdsection=""
	etcdenable="false"
	etcdcommand="stop"
else
	etcdenable="true"
	etcdcommand="start"
etcdsection=$(cat << EOF
[Service]
Environment="ETCD_IMAGE_TAG=v3.2.2"
Environment="ETCD_USER=root"
Environment="ETCD_DATA_DIR=/var/lib/etcd"
Environment="ETCD_SSL_DIR=/etc/kubernetes/ssl/"
Environment="ETCD_OPTS=--name %HOST% \
  --listen-client-urls https://0.0.0.0:2379 \
  --advertise-client-urls https://%ETCDADVERTISEIP%:2379 \
  --listen-peer-urls https://0.0.0.0:2380 \
  --initial-advertise-peer-urls https://%IP%:2380 \
  --initial-cluster %ETCD_INITIAL_CLUSTER% \
  --initial-cluster-token mytoken \
  --initial-cluster-state %ETCD_INITIAL_CLUSTER_STATE% \
  --client-cert-auth \
  --trusted-ca-file /etc/ssl/certs/ca.pem \
  --cert-file /etc/ssl/certs/%NODETYPE%.pem \
  --key-file /etc/ssl/certs/%NODETYPE%-key.pem \
  --peer-client-cert-auth \
  --peer-trusted-ca-file /etc/ssl/certs/ca.pem \
  --peer-cert-file /etc/ssl/certs/%NODETYPE%.pem \
  --peer-key-file /etc/ssl/certs/%NODETYPE%-key.pem \
  --auto-compaction-retention 1"
EOF
)
etcdsection=$(echo "$etcdsection"|sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n'|sed 's/\\n$//g')
fi
cat tmp/certonly-tpl.yaml2a | sed -e "s/%ETCDSECTION%/$etcdsection/g" >  tmp/certonly-tpl.yaml2s
cat tmp/certonly-tpl.yaml2s | sed -e "s/%ETCDENABLE%/$etcdenable/g" >  tmp/certonly-tpl.yaml2d
cat tmp/certonly-tpl.yaml2d | sed -e "s/%ETCDENABLE%/$etcdenable/g" >  tmp/certonly-tpl.yaml2e
cat tmp/certonly-tpl.yaml2e | sed -e "s/%ETCDCOMMAND%/$etcdcommand/g" >  tmp/certonly-tpl.yaml2

#ROOT SSH keys
rootsshkeys=$(cat ssh/root|sed -e 's/\(.*\)/  \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n'|sed 's/\\n$//g')
cat tmp/certonly-tpl.yaml2 | sed -e "s/%ROOTSSHKEYS%/$rootsshkeys/g" >  tmp/certonly-tpl.yaml2b
#users
if [ ! -z "$(for user in password/*;do basename $user; done)" ]; then
	for user in password/*; do
		user=$(basename $user)
		password=$(cat password/$user)
		keys=$(cat ssh/$user|sed "s/^/      /g")
		rm tmp/user_$user
		echo "  - name: \"$user\"">tmp/user_$user
		echo "    passwd: \"$password\"">>tmp/user_$user
		echo "    groups:">>tmp/user_$user
		echo "     - \"sudo\"">>tmp/user_$user
		echo "     - \"docker\"">>tmp/user_$user
		echo "    ssh_authorized_keys:">>tmp/user_$user
		echo "$keys">>tmp/user_$user
	done
fi
users=$(cat tmp/user_*|sed -e 's/\(.*\)/\1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n'|sed 's/\\n$//g')
cat tmp/certonly-tpl.yaml2b | sed -e "s/%USERS%/$users/g" > tmp/certonly-tpl.yaml2c

# bash templating
rm -f inventory/node-${HOST}/cloud-config/openstack/latest/user_data
cat tmp/certonly-tpl.yaml2c | \
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

./build-image.sh inventory/node-${HOST}

rm tmp/*

echo "$@" > inventory/node-${HOST}/parameters
