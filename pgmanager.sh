#!/bin/sh

. /etc/play_backup.config

usage () {
  printf 'Usage:\n%s mkslave <HostName>\n' $0
  printf '%s promotemaster <HostName>\n' $0
  printf '%s setvip <IP>\n' $0
  printf '%s unsetvip <IP>\n' $0
  exit 1
}

if [ "$1" = "-h" -o "$1" = "--help" ]
then
  usage
fi

checkUser () {

  RootUser=`echo $1 | grep -i 'root'`

  if [ ! -z $RootUser ]
  then
    return 0
  else
    return 1
  fi
}

RunUser=`id`

checkUser $RunUser
result=$?

if [ $result -eq 0 ]
then
  User='root'
else
  printf 'Please run scrHostNamet %s as root\n' $0
  exit $result
fi

PgUser='postgres'
RsyncDir="/var/lib/pgsql/${PGVERSION}/data/"
ExcludeList='/var/lib/pgsql/exclude.lst'
PgConfig='postgresql.conf'
HostName=''
tmpFile=`mktemp`

getHost () {
    if [ -z "$1" ]
    then
        HostName=$SLAVE_SRV
    else
        HostName=$1
    fi
}

checkSSH () {
        local user=${1}
        local host=${2}
        local timeout=${3}

ssh -q -o "BatchMode=yes" -o "ConnectTimeout=${timeout}" ${user}@${host} "echo -n 2>&1" && return 0
}

testSSH () {
    checkSSH $1 $HostName $3
    if [ $? -ne 0 ]
    then
        printf 'Host is down, %s exiting...\n' $HostName
        exit 1
    else
        printf 'Host is up\n'
    fi
}

testIP () {
    if [ "X$1" == "X" ]
    then
        printf 'No IP address specified\n'
        exit 1
    else
        local ip=$1
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
        then
            ping -q -c3 $ip > /dev/null 2>&1 
            RES=$?
            if [ $RES -eq 0 ]
            then
                return 110
            else
                if [ -x `which arping` ]
                then
                    arping -q -c3 $ip
                    RES=$?
                    if [ $RES -eq 0 ]
                    then
                        return 120
                    else
                        return 0
                    fi
                else
                    printf "Can't find arping utility, exiting\n"
                    exit 1
                fi
            fi
        else
            printf 'Not a valid IP address\n'
            exit 1
        fi
    fi
}

operateVIP () {
    local ip=$1
    local operation=$2
    if [ $operation == "up" ]
    then
        /sbin/ifup `grep $1 -iHr /etc/sysconfig/network-scripts/ | awk -F':' '{print $1":"$2}' | awk -F '-' '{print $3}'`
    elif [ $operation == "down" ]
    then
        /sbin/ifconfig | grep -q $1
        RES=$?
        if [ $RES -eq 0 ]
        then
            /sbin/ifdown `grep $1 -iHr /etc/sysconfig/network-scripts/ | awk -F':' '{print $1":"$2}' | awk -F '-' '{print $3}'`
        else
            printf "Can't find IP %s in local interfaces\n" $1
            exit 1
        fi
    else
        printf 'Unsupported operation %s, exiting\n' $operation
        exit 1
    fi
    
    RES=$?
    if [ $RES -eq 0 ]
    then
        printf 'IP %s is %s\n' $1 $operation
    else
        printf "Can't %s IP\n" $1 $operation
        exit 1
    fi
}

generateRecoveryConf() {
cat <<EOF >> $1
    standby_mode = 'on'
    primary_conninfo = 'host=$VIP_MASTER port=5433 user=postgres application_name=$2 '
    restore_command = '/usr/local/bin/omnipitr-restore -sr -r %r -v -l /var/log/omnipitr/omnipitr-restore^Y-^m-^d.log -s gzip=/backups/preproduction/muvi_archive/ %f %p '
    recovery_target_timeline = 'latest'
EOF
}
 
mkslave () {
    testSSH $User $HostName 3
    ssh $User@$HostName  "service postgresql-${PGVERSION} stop"
    su - $PgUser -c "psql -c \"SELECT pg_start_backup('mkslave',true)\""
    su - $PgUser -c "rsync -e 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' -avr --delete $RsyncDir $HostName:$RsyncDir --exclude-from $ExcludeList"
    su - $PgUser -c "psql -c 'SELECT pg_stop_backup()'"
    ssh $User@$HostName  "rm -rf /var/lib/pgsql/${PGVERSION}/data/pg_xlog/*"
    generateRecoveryConf $tmpFile $HostName
    scp $tmpFile $User@$HostName:"/var/lib/pgsql/${PGVERSION}/data/recovery.conf"
    ssh $User@$HostName "chown postgres.postgres /var/lib/pgsql/${PGVERSION}/data/recovery.conf"
    ssh $User@$HostName "service postgresql-${PGVERSION} start"
}

promotemaster () {
    testSSH $User $HostName 3
    ssh $User@$HostName "su - $PgUser -c '$PGCTLBIN promote -D $PGDATA'"
    RES=$?
    if [ $RES -eq 0 ]
    then
        printf 'Master successfully promoting\n'
    else
        printf "Can't promote master\n"
        exit $RES
    fi
}

setvip () {
    testIP $1
    case $? in
        0)
        operateVIP $1 'up'
        ;;
        110)
        printf 'ping check fail, IP %s already in use\n' $1
        ;;
        120)
        printf 'arping check fail, IP %s already in use\n' $1
        ;;
        *)
        printf 'Something unhandled\n'
        ;;
    esac
}

unsetvip () {
    testIP $1
    case $? in
        0)
        printf 'IP %s already down\n' $1
        ;;
        110)
        operateVIP $1 'down'
        ;;
        120)
        downVIP $1 'down'
        ;;
        *)
        printf 'Something unhandled\n'
        ;;
    esac
}

case $1 in
    "mkslave")
    test "X$2" == "X" && getHost || getHost $2
    mkslave
    ;;
    "promotemaster")
    test "X$2" == "X" && getHost || getHost $2
    promotemaster
    ;;
    "setvip")
    shift
    setvip $1
    ;;
    "unsetvip")
    shift
    unsetvip $1
    ;;
    *)
    usage
    ;;
esac
