#!/bin/sh

SUFFIX=$(date '+%Y-%m-%d')
GPGPASS='pass'
RECIPIENT='nobody@example.com'
BCPDIRPREFIX='/exports/backups/play/production/'
BCPDIRSUFFIX='/basebackup/'
BASEBACKUPFILE='base_'${SUFFIX}'.tar.bz2'
BASEBACKUPFILEGPG=${BASEBACKUPFILE}'.gpg'
GPGRESTOREDIR='/exports/backups/postgres/'
GPGBIN='/usr/bin/gpg'

usage() {
  printf 'Usage:\n%s -m MASTERHOST1:RESTOREPORT,MASERHOST2:RESTOREPORT,...MASTERHOSTn:RETOREPORTn\n' $0
}

while getopts ":hm:" opt
do
  case $opt in
    m)
      masterhost=$OPTARG
      ;;
    h)
      usage
      exit 0
    ;;
    \?)
      printf 'Invalid option: -%s\n' $OPTARG >&2
      usage
      exit 1
      ;;
    :)
      printf 'Option -%s requires an argument.\n' $OPTARG >&2
      usage
      exit 1
      ;;
  esac
done 

for mdb in $(echo $masterhost | awk -F',' '{for (i=1; i<=NF; i++) print $i}')
do
  DB=$(echo $mdb | awk -F':' '{print $1}')
  PGPORT=$(echo $mdb | awk -F':' '{print $2}')

  if [ -z "$DB" ]
  then
    usage
  fi

  if [ -z "$PGPORT" ]
  then
    prinf 'Using default postgresql port 5432\n'
    PGPORT='5432'
  fi

  if [ -f $BCPDIRPREFIX${DB}${BCPDIRSUFFIX}${BASEBACKUPFILEGPG} ]
  then
    $GPGBIN --verify-files $BCPDIRPREFIX${DB}${BCPDIRSUFFIX}${BASEBACKUPFILEGPG} > /dev/null 2>&1
    RES=$?
    if [ $RES -eq 0 ]
    then
      printf 'GPG encrypted file\n'
      /usr/bin/gpg --batch --passphrase ${GPGPASS} --output ${GPGRESTOREDIR}${BASEBACKUPFILE} --recipient ${RECIPIENT} --decrypt $BCPDIRPREFIX${DB}${BCPDIRSUFFIX}${BASEBACKUPFILEGPG} > /dev/null 2>&1
      /usr/bin/python /var/lib/postgresql/utils/checkBackup.py -a ${GPGRESTOREDIR}${BASEBACKUPFILE} -d ${GPGRESTOREDIR}${DB} -p ${PGPORT}
      rm -f ${GPGRESTOREDIR}${BASEBACKUPFILE}
    else
      printf 'None GPG encrypted file, but with gpg suffix, skip file %s\n' $BCPDIRPREFIX${DB}${BCPDIRSUFFIX}${BASEBACKUPFILEGPG}
    fi
  elif [ -f $BCPDIRPREFIX${DB}${BCPDIRSUFFIX}${BASEBACKUPFILE} ]
  then
    printf 'Simple basebackup archive\n'
   /usr/bin/python /var/lib/postgresql/utils/checkBackup.py -a $BCPDIRPREFIX${DB}${BCPDIRSUFFIX}${BASEBACKUPFILE} -d ${GPGRESTOREDIR}${DB} -p ${PGPORT}
  else
    printf "Can't find basebackup archive in %s\n" $BCPDIRPREFIX${DB}${BCPDIRSUFFIX}
  fi
done
