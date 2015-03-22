#!/bin/sh
bad_block_file='under_replicated_blocks.txt'
hdfs fsck / | awk '{print $1}'|grep -i mapred|tr -d ':' | sort | uniq > $bad_block_file
for hdfsfile in `cat $bad_block_file`
do
  hadoop fs -setrep -w 3 $hdfsfile
  #echo $hdfsfile
done
rm -f $bad_block_file
