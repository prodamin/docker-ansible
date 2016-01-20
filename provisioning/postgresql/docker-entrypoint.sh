#!/bin/bash
set -e

set_listen_addresses() {
	sedEscapedValue="$(echo "$1" | sed 's/[\/&]/\\&/g')"
	sed -ri "s/^#?(listen_addresses\s*=\s*)\S+/\1'$sedEscapedValue'/" "$PGDATA/postgresql.conf"
}

#################################### MASTER ################################
master() {
/bin/echo -e "                                       \
host    all             all     0.0.0.0/0   md5      \n  \
host    replication     all     0.0.0.0/0   trust    \n  \
    " >> ${PGDATA}/pg_hba.conf
cat ${PGDATA}/pg_hba.conf | tail -2

/bin/echo -e "                  \
listen_addresses = '*'          \n  \
port=5432                       \n  \
hot_standby = on                \n  \
wal_level = 'hot_standby'	\n  \
archive_mode = on		\n  \
archive_command = 'cd .'	\n  \
max_wal_senders = 2		\n  \
    " >> ${PGDATA}/postgresql.conf
}
################################ END MASTER ################################


#################################### SLAVE ################################
slave() {
/bin/echo -e "                                               \
        host    all             all     0.0.0.0/0   md5      \n  \
        host    replication     all     0.0.0.0/0   trust    \n  \
    " >> ${PGDATA}/pg_hba.conf
cat ${PGDATA}/pg_hba.conf | tail -2

/bin/echo -e "                                  \
listen_addresses = '*'                  \n  \
port=5432                               \n  \
hot_standby = on                        \n  \
wal_level = 'hot_standby'               \n  \
archive_mode = on                       \n  \
archive_command = 'cd .'                \n  \
max_wal_senders = 2                     \n  \
    " >> ${PGDATA}/postgresql.conf
cat ${PGDATA}/postgresql.conf | tail -3

/bin/echo -e "                                            \
standby_mode='on'                                 \n  \
primary_conninfo = 'host=master port=5432'        \n  \
trigger_file = '/tmp/trigger_file0'               \n  \
    " > ${PGDATA}/recovery.conf

}
################################ END SLAVE ################################

slave-run() {
    echo "Run postgresql as SLAVE"
    echo "start create directory $PGDATA"
    mkdir -p "$PGDATA"
    chmod 700 "$PGDATA"
    chown -R postgres "$PGDATA"
    chmod g+s /run/postgresql
    chown -R postgres /run/postgresql
    # look specifically for PG_VERSION, as it is expected in the DB dir
    if [ ! -s "$PGDATA/PG_VERSION" ]; then
        echo "start initdb..."
        su -l postgres -c "/usr/lib/postgresql/9.4/bin/initdb"
    fi
    if [ ! -d /var/lib/postgresql/data2 ]; then
	echo configure slave
    	slave
	/usr/bin/pg_basebackup -h master -p 5432 -D /var/lib/postgresql/data2 -U postgres -v -P -x
	cp /var/lib/postgresql/data/recovery.conf /var/lib/postgresql/data2
	cp /var/lib/postgresql/data/postgresql.conf /var/lib/postgresql/data2
    fi
    chown -R postgres:postgres /var/lib/postgresql/data2

    #
    # Start the postgresql server as SLAVE
    #
    su -l postgres -c "/usr/lib/postgresql/9.4/bin/postgres -D /var/lib/postgresql/data2 -c config_file=/var/lib/postgresql/data2/postgresql.conf"
}





# create postgres env
dir="/home/postgres"
bashrc="${dir}/.bash_profile"

if [ ! -d ${dir} ] || [ ! -f ${bashrc} ]
    then
        echo create directory ${dir}
        mkdir -p ${dir}
        touch ${bashrc}
        echo export PGDATA="${PGDATA}"          >> ${bashrc}
        echo export PG_MAJOR="${PG_MAJOR}"      >> ${bashrc}
        echo export PG_VERSION="${PG_VERSION}"  >> ${bashrc}
        echo export PATH="${PATH}"              >> ${bashrc}
        chown -R postgres:postgres ${dir}
fi

postgres-master() {

if [ "$1" = 'postgres' ] || [ "$1" = 'master' ] 
then
	mkdir -p "$PGDATA"
	chmod 700 "$PGDATA"
	chown -R postgres "$PGDATA"

	chmod g+s /run/postgresql
	chown -R postgres /run/postgresql

	# look specifically for PG_VERSION, as it is expected in the DB dir
	if [ ! -s "$PGDATA/PG_VERSION" ]; then
		su -l postgres -c "/usr/lib/postgresql/9.4/bin/initdb"

		# check password first so we can output the warning before postgres
		# messes it up
		if [ "$POSTGRES_PASSWORD" ]; then
			pass="PASSWORD '$POSTGRES_PASSWORD'"
			authMethod=md5
		else
			# The - option suppresses leading tabs but *not* spaces. :)
			cat >&2 <<-'EOWARN'
				****************************************************
				WARNING: No password has been set for the database.
				         This will allow anyone with access to the
				         Postgres port to access your database. In
				         Docker's default configuration, this is
				         effectively any other container on the same
				         system.

				         Use "-e POSTGRES_PASSWORD=password" to set
				         it in "docker run".
				****************************************************
			EOWARN

			pass=
			authMethod=trust
		fi

		{ echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA/pg_hba.conf"


        if [ "$1" = 'master' ]
            then
            master
        fi

		# internal start of server in order to allow set-up using psql-client		
		# does not listen on TCP/IP and waits until start finishes
		su -l postgres -c "/usr/lib/postgresql/9.4/bin/pg_ctl -D ${PGDATA} -w start"


		: ${POSTGRES_USER:=postgres}
		: ${POSTGRES_DB:=$POSTGRES_USER}
		export POSTGRES_USER POSTGRES_DB

		if [ "$POSTGRES_DB" != 'postgres' ]; then
			psql --username postgres <<-EOSQL
				CREATE DATABASE "$POSTGRES_DB" ;
			EOSQL
			echo
		fi

		if [ "$POSTGRES_USER" = 'postgres' ]; then
			op='ALTER'
		else
			op='CREATE'
		fi

		psql --username postgres <<-EOSQL
			$op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
		EOSQL
		echo

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)  echo "$0: running $f"; . "$f" ;;
				*.sql) echo "$0: running $f"; psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < "$f" && echo ;;
				*)     echo "$0: ignoring $f" ;;
			esac
			echo
		done

		#gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop
		su -l postgres -c "/usr/lib/postgresql/9.4/bin/pg_ctl -D ${PGDATA} -m fast -w stop"
		set_listen_addresses '*'

		echo
		echo 'PostgreSQL init process complete; ready for start up.'
		echo
	fi

	#exec gosu postgres "$@"
	#exec su -l postgres -c "$@"
	#su -l postgres -c "/usr/lib/postgresql/9.4/bin/pg_ctl -D ${PGDATA} -w start"
	su -l postgres -c "/usr/lib/postgresql/9.4/bin/postgres -D /var/lib/postgresql/data -c config_file=/var/lib/postgresql/data/postgresql.conf"
fi

}
# main 

case $1 in
    postgres)      
	echo "start $1   #############"
        postgres-master $1
        ;;
    master)      
	echo "start $1   #############"
        postgres-master $1
        ;;
    slave)
	echo "start $1   #############"
        slave-run $1
        ;; 
    *)
	    echo "help: "
	    echo "cmd: postgres - for standart instalation"
	    echo "cmd: master   - for master instalation"
	    echo "cmd: slave    - for slave instalation"
    ;;
esac

#echo 1
#exec "$@"
#echo 2
