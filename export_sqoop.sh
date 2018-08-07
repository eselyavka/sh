#!/bin/bash
set -Cvx

test -f "$1" || { echo "file '${1}' doesn't exists"; exit 1; }

DB_CONN_STRIN="jdbc:mysql://127.0.0.1/db"
DB_USER="DB_USER"
DB_PASSWD="DB_PASSWD"
BUCKET_SIZE="10"

function sqoop_export {
    local table_name="$1"
    local param1="$2"
    local param2="$3"

    sqoop import --connect "${DB_CONN_STRIN}" --username "${DB_USER}" --password "${DB_PASSWD}" --hive-import --hive-database default --table "${table_name}" --as-parquetfile

    return "$?"
}

function main {
    local file_name="$1"
    declare -a tables
    declare -a rcs
    declare -i i=0
    declare -i size
    local -i reminder
    local table_name
    local param1
    local param2

    readarray -t tables < "${file_name}"

    size="$(( ${#tables[@]} - 1 ))"

    while [ "${i}" -lt "${size}" ] ; do
        table_name="$(awk -F',' '{print $1}' <<<"${tables[${i}]}")"
        param1="$(awk -F',' '{print $2}' <<<"${tables[${i}]}")"
        param2="$(awk -F',' '{print $3}' <<<"${tables[${i}]}")"

        sqoop_export "${table_name}" "${param1}" "${param2}"

        rcs+=( "$?" )
        let "reminder=${#rcs[@]} % ${BUCKET_SIZE}"

        if [[ "${reminder}" -eq "0" ]] ; then
            grep -q 1 <<<"${rcs[*]}" && { i="$((i-10))"; rcs=( ); }
        fi

        i="$((i+1))"
    done
}

main "$1"
