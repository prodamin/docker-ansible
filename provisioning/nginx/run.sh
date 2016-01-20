#!/bin/sh

upstream="/etc/nginx/upstream/upstream.conf"

echo "create stream pool from link php-fpm"
env | grep ENV_PHPSERVER=true | sed 's/_.*//g'


if [ `env | grep ENV_PHPSERVER=true | sed 's/_ENV_PHPSERVER.*//g' | wc -l` -lt 1 ]
then
echo "no PHPFPM servers found"
exit 1
fi


echo "create upstream.conf"
echo "upstream php-fpm {" > ${upstream}
for phpfpm in `cat /etc/hosts | awk '{ print $2 }' `
do
	docker_host=`echo ${phpfpm} | sed 's/-/_/g'`
	if [ `env | grep ENV_PHPSERVER=true | grep -i ${docker_host}` ]
	then
		echo "server ${phpfpm}:9000;" >> ${upstream}
	fi
done
echo "}" >> ${upstream}



echo "clone git repo"
if [ ! -z "$GIT_REPO" ]
 then
  rm -rf /usr/share/nginx/html/*
  rm -rf /usr/share/nginx/html/.*
    git clone $GIT_REPO /usr/share/nginx/html/
  chown -Rf nginx:nginx /usr/share/nginx/*
else
	echo "ERROR: Git repo not found"
	exit 1
fi


# start nginx
echo "start nginx"
nginx -g "daemon off;"
