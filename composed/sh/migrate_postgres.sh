#!/bin/bash
: ${DB_ENV_POSTGRES_USER:=postgres}
: ${DB_ENV_POSTGRES_SCHEMA:=postgres}

echo "wait for postgres to be ready"

while ! nc -q 1 $POSTGRES_HOST $POSTGRES_PORT </dev/null;
do
  echo "Waiting for database"
  sleep 10;
done

cat <<CONF > /migrate/environments/development.properties
time_zone=GMT+0:00
driver=org.postgresql.Driver
url=jdbc:postgresql://$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_OPENSRP_DATABASE
username=$POSTGRES_OPENSRP_USER
password=$POSTGRES_OPENSRP_PASSWORD
script_char_set=UTF-8
send_full_script=true
delimiter=;
full_line_delimiter=false
auto_commit=true
changelog=changelog
core_tablespace_location='$POSTGRES_OPENSRP_TABLESPACE_DIR/core'
error_tablespace_location='$POSTGRES_OPENSRP_TABLESPACE_DIR/error'
schedule_tablespace_location='$POSTGRES_OPENSRP_TABLESPACE_DIR/schedule'
feed_tablespace_location='$POSTGRES_OPENSRP_TABLESPACE_DIR/feed'
form_tablespace_location='$POSTGRES_OPENSRP_TABLESPACE_DIR/form'
CONF

echo $POSTGRES_OPENSRP_TABLESPACE_DIR

mkdir -p $POSTGRES_OPENSRP_TABLESPACE_DIR/core
mkdir -p $POSTGRES_OPENSRP_TABLESPACE_DIR/error
mkdir -p $POSTGRES_OPENSRP_TABLESPACE_DIR/schedule
mkdir -p $POSTGRES_OPENSRP_TABLESPACE_DIR/feed
mkdir -p $POSTGRES_OPENSRP_TABLESPACE_DIR/form

groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

chown -R postgres:postgres $POSTGRES_OPENSRP_TABLESPACE_DIR

/opt/mybatis-migrations-3.3.4/bin/migrate up --path=/migrate

if [ -d /tmp/opensrp-server-${OPENSRP_SERVER_TAG}/assets/tbreach_default_view_configs -a ! -f /etc/migrations/.setup_view_configs_complete ]; then
	/tmp/opensrp-server-${OPENSRP_SERVER_TAG}/assets/tbreach_default_view_configs/setup_view_configs.sh -t postgres  -u $POSTGRES_OPENSRP_USER -pwd $POSTGRES_OPENSRP_PASSWORD -d $POSTGRES_OPENSRP_DATABASE -h postgres -f /tmp/opensrp-server-${OPENSRP_SERVER_TAG}/assets/tbreach_default_view_configs
	echo "Do not remove!!!. This file is generated by Docker. Removing this file will reset view configurations on the database" > /etc/migrations/.setup_view_configs_complete 
elif [ ! -d /tmp/opensrp-server-${OPENSRP_SERVER_TAG}/assets/tbreach_default_view_configs ]; then
	touch  /etc/migrations/.setup_view_configs_complete
fi


if [[ -n $DEMO_DATA_TAG ]];then
	wget --quiet --no-cookies https://s3-eu-west-1.amazonaws.com/opensrp-stage/demo/${DEMO_DATA_TAG}/sql/opensrp.sql.gz -O /tmp/opensrp.sql.gz
	if [[ -f /tmp/opensrp.sql.gz ]]; then
		gunzip  /tmp/opensrp.sql.gz	
		PGPASSWORD=$POSTGRES_OPENSRP_PASSWORD psql -U $POSTGRES_OPENSRP_USER -h $POSTGRES_HOST -d $POSTGRES_OPENSRP_DATABASE -a -f /tmp/opensrp.sql
	fi
fi

