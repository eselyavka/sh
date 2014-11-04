#!/bin/sh

SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
COMPONENT_FILE='./component.map'

if [ -f "$COMPONENT_FILE" ]
then
  . ${COMPONENT_FILE}
else
  echo 'Not set host and runnig components, exiting...'
  exit 1
fi 

echo 'Do you sure you want to STOP HDFS and MRv1 cluster components[y/n]?'

read line

if [ "$line" = "y" -o "$line" = "Y" ]
then 

  echo "Stoping tasktracker servers on $TT"
  for srv in $TT
  do
    ssh $SSH_OPTS $srv "service hadoop-0.20-mapreduce-tasktracker stop" > /dev/null 2>&1 && echo -e "\033[40m\033[32mhadoop-0.20-mapreduce-tasktracker succefully stop on $srv\033[0m" || echo -e "\033[40m\033[31mhadoop-0.20-mapreduce-tasktracker can't stop on $srv\033[0m"
  done

  sleep 3

  echo "Stoping jobtracker server"
  crm_resource --resource JobTracker --set-parameter target-role --meta --parameter-value Stopped && sleep 3 && echo -e "\033[40m\033[32mJobTracker succefully stop\033[0m" || echo -e "\033[40m\033[31mJobTracker can't stop\033[0m"

  sleep 3

  echo "Stoping datanode servers on $DN"
  for srv in $DN
  do
    ssh $SSH_OPTS $srv "service hadoop-hdfs-datanode stop" > /dev/null 2>&1 && echo -e "\033[40m\033[32mhadoop-hdfs-datanode succefully stop on $srv\033[0m" || echo -e "\033[40m\033[31mhadoop-hdfs-datanode can't stop on $srv\033[0m"
  done

  sleep 3

  echo "Stoping SNN server"
  crm_resource --resource SecNameNode --set-parameter target-role --meta --parameter-value Stopped && echo -e "\033[40m\033[32mSecNameNode succefully stop\033[0m" || echo -e "\033[40m\033[31mSecNameNode can't stop\033[0m"

  sleep 3

  echo "Stoping NN server"
  crm_resource --resource NameNode --set-parameter target-role --meta --parameter-value Stopped && echo -e "\033[40m\033[32mNameNode succefully stop\033[0m" || echo -e "\033[40m\033[31mNameNode can't stop\033[0m"

  exit 0

elif [ "$line" = "n" -o "$line" = "N" ]
then
  echo 'Exiting...'
  exit 1
else
  printf "Can't parse argument %s, exiting...\n" $line
  exit 1
fi
