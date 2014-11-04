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

echo 'Do you sure you want to START ALL Hadoop cluster components[y/n]?'

read line

if [ "$line" = "y" -o "$line" = "Y" ]
then 

  echo "Starting NN server"
  crm_resource --resource NameNode --set-parameter target-role --meta --parameter-value Started && echo -e "\033[40m\033[32mNameNode succefully start\033[0m" || echo -e "\033[40m\033[31mNameNode can't start\033[0m"

  sleep 3

  echo "Starting SNN server"
  crm_resource --resource SecNameNode --set-parameter target-role --meta --parameter-value Started && echo -e "\033[40m\033[32mSecNameNode succefully start\033[0m" || echo -e "\033[40m\033[31mSecNameNode can't start\033[0m"

  sleep 3

  echo "Starting datanode servers on $DN"
  for srv in $DN
  do
    ssh $SSH_OPTS $srv "service hadoop-hdfs-datanode start" > /dev/null 2>&1 && echo -e "\033[40m\033[32mhadoop-hdfs-datanode succefully start on $srv\033[0m" || echo -e "\033[40m\033[31mhadoop-hdfs-datanode can't start on $srv\033[0m"
  done

  sleep 3

  echo "Starting jobtracker server"
  crm_resource --resource JobTracker --set-parameter target-role --meta --parameter-value Started && echo -e "\033[40m\033[32mJobTracker succefully start\033[0m" || echo -e "\033[40m\033[31mJobTracker can't start\033[0m"

  sleep 3

  echo "Starting tasktracker servers on $TT"
  for srv in $TT
  do
    ssh $SSH_OPTS $srv "service hadoop-0.20-mapreduce-tasktracker start" > /dev/null 2>&1 && echo -e "\033[40m\033[32mhadoop-0.20-mapreduce-tasktracker succefully start on $srv\033[0m" || echo -e "\033[40m\033[31mhadoop-0.20-mapreduce-tasktracker can't start on $srv\033[0m"
  done

  sleep 3

  echo "Starting zookeeper servers on $ZK"
  for srv in $ZK
  do
    ssh $SSH_OPTS $srv "service zookeeper-server start" > /dev/null 2>&1 && echo -e "\033[40m\033[32mzookeeper-server succefully start on $srv\033[0m" || echo -e "\033[40m\033[31mzookeeper-server can't start on $srv\033[0m"
  done

  sleep 3

  echo "Starting HBASE-Master servers"
  crm_resource --resource HbaseMaster --set-parameter target-role --meta --parameter-value Started && echo -e "\033[40m\033[32mhbase-master succefully start\033[0m" || echo -e "\033[40m\033[31mhbase-master can't start\033[0m"

  sleep 3

  echo "Starting HBASE-Region servers on $RS"
  for srv in $RS
  do 
    ssh $SSH_OPTS $srv "service hbase-regionserver start" > /dev/null 2>&1 && echo -e "\033[40m\033[32mhbase-regionserver succefully start on $srv\033[0m" || echo -e "\033[40m\033[31mhbase-regionserver can't start on $srv\033[0m"
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
