#!/bin/sh

usage()
{
  printf '%s <postgres user> <postgres host>, default is <postgres> <localhost>\n' $0
  exit 0
}

if [ "$1" = "-h" -o "$1" = "--help" ]
then
  usage
fi

if [ -z $1 ]
then
  PgUser='postgres'
else
  PgUser=$1
fi

if [ -z $2 ]
then
  PgHost='localhost'
else
  PgHost=$2
fi

ActiveNodeCount=`psql -qAt -U $PgUser -h $PgHost -c 'show pool_nodes' | cut -d '|' -f 4 | grep 2 | wc -l`
AllPoolConnected=`psql -qAt -U $PgUser -h $PgHost -c 'show pool_pools' | cut -d '|' -f 12 | grep 1 | wc -l`
NumChildren=`psql -qAt -U $PgUser -h $PgHost -c 'show pool_status' | grep -i 'num_init_children' | cut -d '|' -f 2`
UserConnected=`expr $AllPoolConnected / $ActiveNodeCount`
NagiosVar=`expr $NumChildren - $UserConnected`

if [ "$NagiosVar" -le 10 ]
then
  printf 'Critical: Too many connection to pgpool %d' $NagiosVar
  exit 2
elif [ "$NagiosVar" -le 20 ]
then
  printf 'Warning: Many connection to pgpool %d' $NagiosVar
  exit 1
else 
  printf 'OK: Connection to pgpool %d' $NagiosVar
  exit 0
fi
