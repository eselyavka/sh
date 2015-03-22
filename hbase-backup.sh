#!/bin/bash

. /etc/play_backup.config

_SUFFIX="`date +'%Y_%m_%dT%H_%M_%S'`.tbz2"

function _log { echo $1; logger -t hbasemeta-backup $1; }

PID_FILE="/var/run/`basename $0`.pid"

if [ -e ${PID_FILE} ]; then
    PID=`cat ${PID_FILE}`;
    kill -0 $PID > /dev/null 2>&1;
    _RES=$?
fi;

[ ${_RES} -eq 0 ] && { _log "Another script has already been running: ${PID}" ; exit 1; }

echo $$ > $PID_FILE

if [ ! -d $BACKUP_DIR ]
then
  mkdir -p $BACKUP_DIR
  RES=$?
  if [ $RES -ne 0 ]
  then
    _log "Could not to create $BACKUP_DIR!" && exit -1
  fi
fi

_log "HBASE meta backup..."

[ -d $HBASE_LOCAL_TMP_DIR ] && _log "Removing previous tmpdir: $HBASE_LOCAL_TMP_DIR" && rm -rf $HBASE_LOCAL_TMP_DIR

mkdir -p $HBASE_LOCAL_TMP_DIR

chown $HBASE_SYSTEM_USER:$HBASE_SYSTEM_GROUP $HBASE_LOCAL_TMP_DIR

for D in $HBASE_BACKUP_DIRS; do 
	su - hdfs -c "hadoop fs -copyToLocal $D $HBASE_LOCAL_TMP_DIR"; 
	_log "Backup: $D"
done;

tar -cjf  $BACKUP_DIR/hbasemeta-$_SUFFIX $HBASE_LOCAL_TMP_DIR || exit 1

rm -rf $HBASE_LOCAL_TMP_DIR

find $BACKUP_DIR -mtime +21 -delete

_log "Backup has been complete";
exit 0
