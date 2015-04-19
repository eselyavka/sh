#!/bin/sh

pg_dumpall -r > roles.sql
psql -qAtX -c "select datname from pg_database where datallowconn order by pg_database_size(oid) desc" | \
    xargs -d'\n' -I{} -P2 pg_dump -Fc -f pg-{}.dump {}