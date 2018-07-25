#!/bin/bash

if [ -z "$(echo "$1")" ] ; then
	echo "Enter path to root ssh key/s to add"
else
	if [ ! -f $1 ]; then
		echo "File $1 don't exist"
	else
		if [ -z "$(cat $1|grep "ssh-rsa")" ]; then
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
				done < $1 >> ssh/root
				cat ssh/root|sort|uniq>ssh/root.1; mv ssh/root.1 ssh/root
				cat ssh/root
		fi
	fi
fi
