#!/bin/bash

cd $(dirname $0)/..
. config.inc

git pull > /dev/null


HTTP_STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" -H "Authorization: $QONTO_IDENTIFIANT:$QONTO_SECRET" "https://thirdparty.qonto.com/v2/transactions?slug=$QONTO_IDENTIFIANT&iban=$QONTO_IBAN")

if test $HTTP_STATUS_CODE -ne "200"; then
	echo "Le webservice retourne une erreur : $HTTP_STATUS_CODE (http status code)"
	exit 1
fi

echo "date,\"raw\",amount,type,id,rdate,vdate,\"label\"" > $HISTORY_FILE".new"

curl -s -H "Authorization: $QONTO_IDENTIFIANT:$QONTO_SECRET" "https://thirdparty.qonto.com/v2/transactions?slug=$QONTO_IDENTIFIANT&iban=$QONTO_IBAN&status\[\]=completed&status\[\]=pending" | jq '.transactions[]' | jq -c "[.emitted_at,.label,.reference,.side,.amount,.operation_type,\"$QONTO_COMPTEBANCAIRE_NOM\",.emitted_at,.emitted_at,.label,.reference]" | sed 's/,"debit",/,-/' | sed 's/,"credit",/,/' |  sed -r 's/"([0-9\-]+)T[0-9:\.]+Z"/\1/g' | sed -r "s/,\"([^,\"]+)\",\"($QONTO_COMPTEBANCAIRE_NOM)\",/,\1,\2,/" | sed 's/,null/,""/g' | sed 's/","/ /g' | sed 's/ "/"/g' | sed -r 's/\[//' | sed 's/\]//' >> $HISTORY_FILE".new"

grep "$QONTO_COMPTEBANCAIRE_NOM" $HISTORY_FILE | tail -n +15 > $HISTORY_FILE".old"
grep -v "$QONTO_COMPTEBANCAIRE_NOM" $HISTORY_FILE >> $HISTORY_FILE".old"
cat $HISTORY_FILE".new" $HISTORY_FILE".old" | sed 's/,\(2[0-9-]*\),null,/,\1,\1,/' | awk -F "," 'BEGIN { FPAT = "([^,]+)|(\"[^\"]+\")"; OFS="," }{ gsub(",",".", $2); gsub(",",".",$8); print $0 }' | sort -t "," -k 1,3 -ur > $HISTORY_FILE".tmp"
mv $HISTORY_FILE".tmp" $HISTORY_FILE
rm -f $HISTORY_FILE".old" $HISTORY_FILE".new"

git add $HISTORY_FILE
git commit -m "Mise à jour des opérations (qonto)" $HISTORY_FILE > /dev/null

curl -s -H "Authorization: $QONTO_IDENTIFIANT:$QONTO_SECRET" "https://thirdparty.qonto.com/v2/organizations/$QONTO_IDENTIFIANT" | jq '.organization.bank_accounts[]' | jq -c "[\"Quonto\",.balance,.authorized_balance,.currency,\"\",\"$QONTO_COMPTEBANCAIRE_NOM\"]" | sed 's/"//g' | sed 's/\[//' | sed 's/\]//' > $LIST_FILE.tmp

cat $LIST_FILE | grep -v "^label" | grep -v "$QONTO_COMPTEBANCAIRE_NOM" >> $LIST_FILE.tmp

echo "label,balance,coming,currency,type,id" > $LIST_FILE
cat $LIST_FILE.tmp | sort >> $LIST_FILE
rm $LIST_FILE.tmp

git add $LIST_FILE
git commit -m "Mise à jour du solde (qonto)" $LIST_FILE > /dev/null

git push 2>&1 | grep -v "Everything up-to-date"
