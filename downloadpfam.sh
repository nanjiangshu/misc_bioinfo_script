#!/bin/bash

ftpsite=ftp://ftp.sanger.ac.uk/pub/databases/Pfam/current_release

usage="
Usage: $0 OUTDIR
"

if [ "$1" == "" ];then
    echo "$usage"
    exit
fi

outdir=$1

if [ ! -d $outdir ];then
    mkdir -p $outdir
fi


filelist="
Pfam-A.clans.tsv.gz
Pfam-A.fasta.gz
Pfam-A.hmm.gz
Pfam-A.hmm.dat.gz
Pfam-B.hmm.dat.gz
Pfam-B.hmm.gz
active_site.dat.gz
"

cd $outdir
for file in $filelist; do
    wget $ftpsite/$file -O $file
done

gzip -dN *.gz

hmmpress Pfam-A.hmm
hmmpress Pfam-B.hmm
