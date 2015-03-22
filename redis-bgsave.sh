#!/bin/bash

. /etc/play_backup.config

function _log { echo $1; logger -t redis-bgsave $1; }

if [ -f  $REDIS_CLI_BIN ]
then

  ROLE=`echo 'INFO' | $REDIS_CLI_BIN | grep 'role:slave'`

  if [ ! -z $ROLE ]
  then
    _log "Starting bgsave on redis slave"
    echo 'BGSAVE' | /usr/bin/redis-cli > /dev/null 2>&1
    exit 0
  else
    _log "Server is master, exiting"
    exit 1
  fi
fi
