#!/usr/bin/env bash

declare -i REC_DEPTH=1000
function hdfs_rec_traverse() {
    local path="$1"
    local d
    local dir

    (( $REC_DEPTH == 0 )) && return 123

    dir=$(hdfs dfs -ls "$path" | awk '{if (NF==8) print $8}' | egrep -v '(_|2015|\.gz)+')

    [[ -z "$dir" ]] && return 0

    for d in $dir; do
        echo $d
        (( REC_DEPTH-- ))
        hdfs_rec_traverse "$d"
    done
}
hdfs_rec_traverse "${1:-'path/on/hdfs'}"
