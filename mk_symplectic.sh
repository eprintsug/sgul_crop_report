#!/bin/bash

ATOM_DIR=$1;

for ATOM in `ls $1`
do
	ID=`basename $ATOM`
	XML=`xml_grep "pubs:data-source[string(pubs:source-name)='pubmed']" $1/$ATOM`
	if [[ ${#XML} -gt 0 ]]
	then
		PMID=`echo $XML | xml_grep --text_only "pubs:id-at-source"`
		if [[ ${#PMID} -gt 0 ]]
		then
			echo "$ID,$PMID";
		fi
	fi
done
