#!/bin/sh

usage()
{
  printf 'Usage %s < new master host > < slave1,slave2...slaveN >\n' $0
  exit 1
}

if [ "$1" = '-h' -o "$1" = '--help'  ]
then
  usage
fi

if [ -z "$1" -o -z "$2" ]
then
  usage
fi

test_ssh() {
        local user=${1}
        local host=${2}
        local timeout=${3}

ssh -q -o "BatchMode=yes" -o "ConnectTimeout=${timeout}" ${user}@${host} "echo -n 2>&1" && return 0 || return 1
}

SshUser='root'
MasterHost=$1
SlaveArr=`echo "$2" |  awk -F',' '{ for (i=1; i<=NF; i++) print $i; }'`

test_ssh $SshUser $MasterHost 3

if [ $? -eq 1 ]
then
  printf '%s@%s can not login via ssh' $SshUser $MasterHost
  exit 1;
else
  ssh -o StrictHostKeyChecking=no -T $SshUser@$MasterHost "/usr/bin/redis-cli SLAVEOF NO ONE"
  ssh -o StrictHostKeyChecking=no -T $SshUser@$MasterHost "/usr/bin/redis-cli CONFIG SET save ''"
fi

for Host in $SlaveArr
do

  test_ssh $SshUser $Host 3
  if [ $? -eq 1 ]
  then
    printf '%s@%s can not login via ssh' $SshUser $Host
    exit 1;
  else
    ssh -o StrictHostKeyChecking=no -T $SshUser@$Host "/usr/bin/redis-cli SLAVEOF $MasterHost 6379"
    ssh -o StrictHostKeyChecking=no -T $SshUser@$Host "/usr/bin/redis-cli CONFIG SET save '900 1 300 10 60 10000'"
  fi
done
