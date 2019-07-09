#!/bin/bash

. bin/config.inc

git pull

if [ ! -f $HISTORY_FILE ]
then
    echo "date,raw,amount,type,id,rdate,vdate,label" > $HISTORY_FILE
fi

boobank history $ACCOUNT_ID -n 20 -f csv | sed -r 's/^@//' | awk -F ';' '{ print $3 ",\"" $7 "\"," $10 "," $6 "," $1 "," $4 "," $5 ",\"" $9 "\"" }' | grep -E "^[0-9]+" >> $HISTORY_FILE".new"
tail -n +10 $HISTORY_FILE > $HISTORY_FILE".old"
cat $HISTORY_FILE".new" $HISTORY_FILE".old" | sort| uniq | sort -r > $HISTORY_FILE".tmp"
mv $HISTORY_FILE".tmp" $HISTORY_FILE
rm -f $HISTORY_FILE".old" $HISTORY_FILE".new"

git diff $HISTORY_FILE

git add $HISTORY_FILE
git commit -m "Mise à jour des opérations" $HISTORY_FILE > /dev/null

boobank list -f csv | grep $ACCOUNT_ID | sed -r 's/^.+@//' | awk -F ';' '{ print $3 "," $8 "," $9 "," $4 "," $7 "," $1}' > $LIST_FILE.tmp

if test $(wc -l $LIST_FILE.tmp | cut -d " " -f 1) -gt 0
then
    echo "label,balance,coming,currency,type,id" > $LIST_FILE
    cat $LIST_FILE.tmp >> $LIST_FILE
fi

rm $LIST_FILE.tmp
git diff $LIST_FILE

git add $LIST_FILE
git commit -m "Mise à jour du solde" $LIST_FILE > /dev/null

git push
