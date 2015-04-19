#!/bin/sh

usage ()
{
  printf 'Usage %s <newmaster>\n' $0
  exit 1
}

if [ "$1" = "-h" -o "$1" = "--help" ]
then
  usage
fi

if [ -z "$1" ]
then
  usage
fi

User='postgres'
Host=$1
PgCtl='/usr/bin/pg_ctlcluster'

test_ssh() {
        local user=${1}
        local host=${2}
        local timeout=${3}

ssh -q -o "BatchMode=yes" -o "ConnectTimeout=${timeout}" ${user}@${host} "echo -n 2>&1" && return 0 || return 1
}

test_ssh $User $Host 3 

if [ $? -ne 0 ]
then
  printf 'New master host is down, %s\n' $Host
  exit 1
else
  printf 'New master host is up\n'
fi

run=`ssh -o StrictHostKeyChecking=no -T $User@$Host "service postgresql status" | awk -F ': ' '{print $2}'`

if [ ! -z "$run" ]
then
  printf 'Postgres run: %s\n' $run
else
  printf 'Postgres on new master not run, exiting...\n'
  exit 1  
fi

CtlVersion=`echo $run | cut -d '/' -f 1`
CtlName=`echo $run | cut -d '/' -f 2`

ssh -o StrictHostKeyChecking=no -T $User@$Host "$PgCtl $CtlVersion $CtlName promote" 
