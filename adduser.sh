#!/bin/bash

user=$1
password=$2
keypath=$3

if [ -z "$(echo "$user")" ] ; then
	echo "Enter username"
	exit 1
fi

if [ -z "$(echo "$password")" ] ; then
	echo "Enter encrypted password (in singe quotes)"
	exit 1
fi

if [ ! -d password ]; then
	mkdir password
fi

echo $password > password/$user
cat password/$user

if [ -z "$(echo "$keypath")" ] ; then
	echo "Enter path to root ssh key/s to add"
else
	if [ ! -f $keypath ]; then
		echo "File $keypath don't exist"
	else
		if [ -z "$(cat $keypath|grep "ssh-rsa")" ]; then
			echo "Coudln't find any ssh-rsa inside"
		else
			if [ ! -d ssh ]; then
				mkdir ssh
			fi
				while read -r line
				do
					if [ ! -z "$(echo "$line")" ]; then
						echo "- $line"
					fi
				done < $keypath >> ssh/$user
				cat ssh/$user|sort|uniq>ssh/$user.1; mv ssh/$user.1 ssh/$user
				cat ssh/$user
		fi
	fi
fi
