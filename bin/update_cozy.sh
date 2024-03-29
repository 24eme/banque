#!/bin/bash

cd $(dirname $0)/..
. config.inc

# Connexion à Cozycloud
COZY_URLAUTH=$(curl -s -X GET -I "$COZY_URLBANK" | grep "location" | tr -d "\r" | cut -d " " -f 2)
COZY_CSRFTOKEN=$(curl -s -X GET "$COZY_URLAUTH" -c /tmp/cozycookie | grep "csrf_token" | sed -r 's/.+value=\"//' | sed -r 's/".+//')
curl -s -b /tmp/cozycookie  -c /tmp/cozycookie "$(curl -s -X POST "$COZY_URLAUTH" -b /tmp/cozycookie -c /tmp/cozycookie -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: application/json' -d "passphrase=$COZY_PASSCRYPTE&csrf_token=$COZY_CSRFTOKEN&long-run-session=1&two-factor-trusted-device-token=&redirect=$COZY_URLBANK" | jq '.redirect' | sed 's/"//g')" > /dev/null
COZY_JWTTOKEN=$(curl -s "$COZY_URLBANK" -b /tmp/cozycookie | grep ";token&#34;:&#34;" | sed -r 's/.+;+token&#34;:&#34;//' | sed -r 's/&#34;.+//')
COZY_URLDATA="https://$(curl -s "$COZY_URLBANK" -b /tmp/cozycookie | grep ";domain&#34;:&#34;" | sed -r 's/.+;domain&#34;:&#34;//' | sed -r 's/&#34;.+//')/data"

git pull

echo "date,\"raw\",amount,type,id,rdate,vdate,\"label\"" > $HISTORY_FILE".new"

curl -s "$COZY_URLDATA/io.cozy.bank.operations/_all_docs?include_docs=true" -b /tmp/cozycookie -H 'Accept: application/json' -H "Authorization: Bearer $COZY_JWTTOKEN" |
	jq -c '.rows[].doc' | grep "\"$COZY_COMPTEBANCAIRE_ID\"" |
	jq -c "[.rawDate,\"|<\",.originalBankLabel,\"|>\",.amount,.automaticCategoryId,\"$COZY_COMPTEBANCAIRE_NOM\",.rawDate,.valueDate,\"|<\",.label,\"|>\"]" |
	sed 's/"//g' | sed 's/|<,/"/g' | sed 's/,|>/"/g' | sed 's/\[//g' | sed 's/^\[//' | sed 's/\]$//' >> $HISTORY_FILE".new"

if test $(cat $HISTORY_FILE".new" | grep -v "^date," | wc -l | grep "0") > /dev/null
then
	echo "Aucun mouvement à récupérer"
	exit 0;
fi

grep "$COZY_COMPTEBANCAIRE_NOM" $HISTORY_FILE | tail -n +15 > $HISTORY_FILE".old"
grep -v "$COZY_COMPTEBANCAIRE_NOM" $HISTORY_FILE >> $HISTORY_FILE".old"
cat $HISTORY_FILE".new" $HISTORY_FILE".old" | sed 's/,\(2[0-9-]*\),null,/,\1,\1,/' | awk -F "," 'BEGIN { FPAT = "([^,]+)|(\"[^\"]+\")"; OFS="," }{ gsub(",",".", $2); gsub(",",".",$8); print $0 }' | sort -t "," -k 1,3 -ur > $HISTORY_FILE".tmp"
mv $HISTORY_FILE".tmp" $HISTORY_FILE
rm -f $HISTORY_FILE".old" $HISTORY_FILE".new"

git add $HISTORY_FILE
git commit -m "Mise à jour des opérations (cozy)" $HISTORY_FILE > /dev/null

curl -s "$COZY_URLDATA/io.cozy.bank.accounts/_all_docs?include_docs=true" -b /tmp/cozycookie -H 'Accept: application/json' -H "Authorization: Bearer $COZY_JWTTOKEN" | jq -c '.rows[].doc' | grep "\"$COZY_COMPTEBANCAIRE_ID\"" | jq -c "[.label,.balance,.comingBalance,.currency,.type,\"$COZY_COMPTEBANCAIRE_NOM\"]" | sed 's/"//g' | sed 's/^\[//' | sed 's/\]$//' > $LIST_FILE.tmp

cat $LIST_FILE | grep -v "^label" | grep -v "$COZY_COMPTEBANCAIRE_NOM" >> $LIST_FILE.tmp

echo "label,balance,coming,currency,type,id" > $LIST_FILE
cat $LIST_FILE.tmp | sort >> $LIST_FILE
rm $LIST_FILE.tmp

git add $LIST_FILE
git commit -m "Mise à jour du solde (cozy)" $LIST_FILE > /dev/null

git push
