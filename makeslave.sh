#!/bin/sh

usage ()
{
  printf 'Usage %s <slave> <master>\n' $0
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
SlaveHost=$1
MasterHost=$2
AppName='standby_'${SlaveHost}
Trigger='/var/run/postgresql/trigger'
SourceDir='/var/lib/postgresql/'
TargetDir='/var/lib/postgresql/'
ExcludeFile='exclude.lst'

test_ssh() {
        local user=${1}
        local host=${2}
        local timeout=${3}

ssh -q -o "BatchMode=yes" -o "ConnectTimeout=${timeout}" ${user}@${host} "echo -n 2>&1" && return 0 || return 1
}

test_ssh $User $SlaveHost 3 

if [ $? -ne 0 ]
then
  printf 'New slave host is down, %s exiting...\n' $SlaveHost
  exit 1
else
  printf 'New slave host is up\n'
fi

test_ssh $User $MasterHost 3 

if [ $? -ne 0 ]
then
  printf 'Master host is down, %s exiting...\n' $MasterHost
  exit 1
else
  printf 'Master host is up\n'
fi

ClusterVersion=`ssh -o StrictHostKeyChecking=no -T $User@$MasterHost "service postgresql status" | awk -F ': ' '{print $2}'`

if [ ! -z "$ClusterVersion" ]
then
  if [ `echo $ClusterVersion | wc -l` -lt 2 ]
  then
    check_postgres_run=`ssh -o StrictHostKeyChecking=no -T $User@$SlaveHost "service postgresql status" | awk -F ': ' '{print $2}'`
  else
    printf 'Several postgresql cluster run on master host: %s\n' $MasterHost 
    exit 1;
  fi
else
  printf 'No postgresql run on master host: %s\n' $MasterHost
  exit 1
fi

if [ ! -z "$check_postgres_run" ]
then
  if [ `echo $check_postgres_run | wc -l` -lt 2 ]
  then
    printf 'Stoping postgresql instance on slave: %s\n' $SlaveHost
    ssh $User@$SlaveHost "service postgresql stop"
  else
    printf 'Several postgresql cluster run on slave host: %s\n' $SlaveHost 
    exit 1
  fi
  else
    check_postgres_run="9.1/main"
fi

if [ ! -d ${SourceDir}${check_postgres_run} ]
then
  printf 'No source directory, %s\n' ${SourceDir}${check_postgres_run}
  exit 1
fi

if [ ! -e $ExcludeFile ]
then
  print 'No exclude file found, %s\n' $ExcludeFile
  exit 1
fi

psql -c "SELECT pg_start_backup('makestandby', true)"

ssh $User@$SlaveHost "rm -rf ${TargetDir}${check_postgres_run}/pg_xlog/*"
rsync -avz -e ssh ${SourceDir}${check_postgres_run} $User@$SlaveHost:${TargetDir}${check_postgres_run} --exclude-from "$ExcludeFile"
#echo rsync -avz -e ssh ${SourceDir}${check_postgres_run} $User@$SlaveHost:${TargetDir}${check_postgres_run} --exclude-from "$ExcludeFile"

if [ $? -eq 0 ]
then
  psql -c "SELECT pg_stop_backup()"
  printf 'Rsync complete succefully\n'
else
  psql -c "SELECT pg_stop_backup()"
  printf 'Rsync complete unsuccefully, can not make slave, exiting...\n'
  exit 1
fi

ssh $User@$SlaveHost "cat > ${TargetDir}${check_postgres_run}/recovery.conf <<EOF
standby_mode = 'on'
trigger_file = '$Trigger'
primary_conninfo = 'host=$MasterHost port=5432 user=postgres password=postgres application_name=$AppName'
EOF"

ssh $User@$SlaveHost "service postgresql start"
