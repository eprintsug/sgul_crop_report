#!/bin/bash

# server running eprints (assumed to be remote)
EPRINTS=
# eprints database connection
DBNAME=
DBUSER=
DBPASS=
# atom files from Elements (assumed to be on $EPRINTS server)
XMLPATH=/path/to/symplectic_xml/

# see http://code.google.com/p/csvfix/
CSVFIX=~/bin/bin/csvfix

# PMC FTP details
FTP_HOST=ftp.ncbi.nlm.nih.gov
FTP_USER=anonymous
FTP_PASS=

echo "Fetching data from $EPRINTS"

ssh $EPRINTS "mysql -u $DBUSER -p$DBPASS $DBNAME -e 'select pid as symplectic_id, eprint_id as eprintid from symplectic_pids'" > symplectic_pid_to_eprintid.tsv
ssh $EPRINTS "mysql -u $DBUSER -p$DBPASS $DBNAME -e 'select eprintid, main from document'" > eprintid_to_document.tsv
ssh $EPRINTS "mysql -u $DBUSER -p$DBPASS $DBNAME -e 'select eprintid, eprint_status, title, pmid, pmcid from eprint'" > eprintid_to_eprint.tsv

echo "Converting $EPRINTS data to CSV"

$CSVFIX read_dsv -s '\t' symplectic_pid_to_eprintid.tsv > symplectic_pid_to_eprintid.csv
$CSVFIX read_dsv -s '\t' eprintid_to_eprint.tsv > eprintid_to_eprint.csv
$CSVFIX read_dsv -s '\t' eprintid_to_document.tsv > eprintid_to_document.csv

echo "Filtering out volatile/license documents"

$CSVFIX remove -f 2 -e 'indexcodes\.txt' -e 'small\.jpg' -e 'medium\.jpg' -e 'preview\.jpg' -e 'lightbox\.jpg' -e 'licence\.docx' -e 'licence\.txt'  eprintid_to_document.csv > eprintid_to_document_filtered.csv

echo "Joining eprint dataobjs to symplectic IDs"

$CSVFIX join -f 1:2 eprintid_to_eprint.csv symplectic_pid_to_eprintid.csv > tmp.csv
$CSVFIX join -oj -f 1:1 tmp.csv eprintid_to_document_filtered.csv > eprints.csv # note -oj (not all eprints will have document?)

echo "Copying $XMLPATH from $EPRINTS"

mkdir -p symplectic_xml
rsync -avh $EPRINTS:$XMLPATH symplectic_xml/

echo "Extracting PMIDs from symplectic_xml"
./mk_symplectic.sh symplectic_xml > symplectic_pmids.csv

echo "Fetching data from EPMC"

ftp -n $FTP_HOST <<END_FTP
quote USER $FTP_USER
quote PASS $FTP_PASS
cd pub/pmc
get file_list.pdf.csv
get PMC-ids.csv.gz
quit
END_FTP

gunzip PMC-ids.csv.gz

echo "Processing EPMC data"

$CSVFIX join -f 3:9 file_list.pdf.csv PMC-ids.csv > joined.csv # OA PDFS WHICH CAN BE LOOKED UP BY PMID..
$CSVFIX join -f 2:14 symplectic_pmids.csv joined.csv > joined_with_symplectic_ids.csv # .. AND BY SYMPLECTIC ID

echo "Joining EPMC data to EPrints data"

$CSVFIX join -oj -f 1:6 joined_with_symplectic_ids.csv eprints.csv > report.csv

echo "Finished"
