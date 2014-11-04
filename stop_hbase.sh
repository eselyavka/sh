#!/bin/sh

SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
COMPONENT_FILE='./component.map'
hostrun=`hostname -f`

if [ -f "$COMPONENT_FILE" ]
then
  . ${COMPONENT_FILE}
else
  echo 'Not set host and runnig components, exiting...'
  exit 1
fi 

echo 'Do you sure you want to STOP HBASE cluster components[y/n]?'

read line

if [ "$line" = "y" -o "$line" = "Y" ]
then 

  echo "Stoping HBASE-Region servers on $RS"
  for srv in $RS
  do 
    ssh $SSH_OPTS $srv "service hbase-regionserver stop" > /dev/null 2>&1 && echo -e "\033[40m\033[32mhbase-regionserver succefully stop on $srv\033[0m" || echo -e "\033[40m\033[31mhbase-regionserver can't stop on $srv\033[0m"
  done

  sleep 3

  echo "Stoping HBASE-Master servers on $HBASE"
  crm_resource --resource HbaseMaster --set-parameter target-role --meta --parameter-value Stopped && echo -e "\033[40m\033[32mhbase-master succefully stop\033[0m" || echo -e "\033[40m\033[31mhbase-master can't stop\033[0m"

  sleep 3

  echo "Stoping zookeeper servers on $ZK"
  for srv in $ZK
  do
    if [ "$hostrun" = "$srv" ]
    then
      service zookeeper-server stop > /dev/null 2>&1 && echo -e "\033[40m\033[32mzookeeper-server succefully stop on $srv\033[0m" || echo -e "\033[40m\033[31mzookeeper-server can't stop on $srv\033[0m"
    else
      ssh $SSH_OPTS $srv "service zookeeper-server stop" > /dev/null 2>&1 && echo -e "\033[40m\033[32mzookeeper-server succefully stop on $srv\033[0m" || echo -e "\033[40m\033[31mzookeeper-server can't stop on $srv\033[0m"
    fi
  done

  exit 0

elif [ "$line" = "n" -o "$line" = "N" ]
then
  echo 'Exiting...'
  exit 1
else
  printf "Can't parse argument %s, exiting...\n" $line
  exit 1
fi
