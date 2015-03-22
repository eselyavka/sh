#!/bin/sh

usage ()
{
  printf '%s <xml> <hbase front url>\n' $0
  exit 1
}

if [ -z "$1" -o -z "$2" ]
then
  usage
fi

if [ "$1" = "-h" -o "$1" = "--help" ]
then
  usage
fi

if [ ! -e $1 ]
then
  printf 'Non-existent file: %s\n' $1
  exit 1
fi

Str=`cat $1`
Salt='yotastatistics_2010'
Md5Str=`echo -n "${Str}${Salt}" | md5sum | awk '{print $1}'`

#echo "wget --header=\"X-Message-Digest: $Md5Str\" --header=\"Content-Type: text/xml\" --post-data=\"`cat $1`\" -d $2"
wget --output-document="/dev/null" --header="X-Message-Digest: $Md5Str" --header="Content-Type: text/xml" --no-proxy --post-data="`cat $1`" -d $2
