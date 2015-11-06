#!/bin/bash
. bin/config.inc

cat $HISTORY_FILE $(boobank history $ACCOUND_ID -n 20 -f csv | awk -F ';' '{ print $2 ";" $6 ";" $9 ";" $1 ";" $3 ";" $4 ";" $5 ";" $8 }' | grep -E "^[0-9]+") | sort | uniq | sort -r > $HISTORY_FILE


