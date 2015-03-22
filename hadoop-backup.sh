#!/bin/bash

. /etc/play_backup.config

_SUFFIX="`date +'%Y_%m_%dT%H_%M_%S'`.tbz2"

function _log { echo $1; logger -t namenode-backup $1; }

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

_log "NameNode meta backup..."

[ -d $HADOOP_LOCAL_TMP_DIR ] && _log "Removing previous tmpdir: $HADOOP_LOCAL_TMP_DIR" && rm -rf $HADOOP_LOCAL_TMP_DIR

mkdir -p $HADOOP_LOCAL_TMP_DIR

if [ -f $BACKUP_SCRIPT ]
then
  /usr/bin/python $BACKUP_SCRIPT -s $HADOOP_NAMENODE -p $HADOOP_NAMENODE_PORT -r 2 --getimage
  /usr/bin/python $BACKUP_SCRIPT -s $HADOOP_NAMENODE -p $HADOOP_NAMENODE_PORT -r 2 --getedits

  cd $HADOOP_LOCAL_TMP_DIR

  tar -cjf $BACKUP_DIR/metadata-$_SUFFIX .

else
  _log "Can't find $BACKUP_SCRIPT"
fi

rm -rf $HADOOP_LOCAL_TMP_DIR

find $BACKUP_DIR -mtime +21 -delete

_log "Backup has been complete";
exit 0
