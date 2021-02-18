#!/bin/bash

cd $(dirname $0)/..
. config.inc

git pull

echo "date,\"raw\",amount,type,id,rdate,vdate,\"label\"" > $HISTORY_FILE".new"

curl -s -H "Authorization: $QONTO_IDENTIFIANT:$QONTO_SECRET" "https://thirdparty.qonto.com/v2/transactions?slug=$QONTO_IDENTIFIANT&iban=$QONTO_IBAN" | jq '.transactions[]' | jq -c "[.settled_at,.label,.reference,.amount,.operation_type,\"$QONTO_COMPTEBANCAIRE_NOM\",.settled_at,.settled_at,.label,.reference]" | sed -r 's/"([0-9\-]+)T[0-9:\.]+Z"/\1/g' | sed -r "s/,\"([^,\"]+)\",\"($QONTO_COMPTEBANCAIRE_NOM)\",/,\1,\2,/" | sed 's/","/ /g' | sed -r 's/\[//' | sed 's/\]//' >> $HISTORY_FILE".new"

grep "$QONTO_COMPTEBANCAIRE_NOM" $HISTORY_FILE | tail -n +15 > $HISTORY_FILE".old"
grep -v "$QONTO_COMPTEBANCAIRE_NOM" $HISTORY_FILE >> $HISTORY_FILE".old"
cat $HISTORY_FILE".new" $HISTORY_FILE".old" | sed 's/,\(2[0-9-]*\),null,/,\1,\1,/' | awk -F "," 'BEGIN { FPAT = "([^,]+)|(\"[^\"]+\")"; OFS="," }{ gsub(",",".", $2); gsub(",",".",$8); print $0 }' | sort -t "," -k 1,3 -ur > $HISTORY_FILE".tmp"
mv $HISTORY_FILE".tmp" $HISTORY_FILE
rm -f $HISTORY_FILE".old" $HISTORY_FILE".new"

git add $HISTORY_FILE
git commit -m "Mise à jour des opérations (qonto)" $HISTORY_FILE > /dev/null

git push
