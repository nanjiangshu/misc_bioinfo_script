#!/bin/bash

# Filename:  update_uniref90.sh
# Description: update the uniref90 database for PSIBLAST
# Author: Nanjiang Shu (nanjiang.shu@scilifelab.se)

progname=`basename $0`
size_progname=${#progname}
wspace=`printf "%*s" $size_progname ""` 
usage="
Usage:  $progname OUTPATH

Created 2016-04-28, updated 2016-04-28, Nanjiang Shu

Examples:
# update the uniref90.fasta blastdb at path /data/blastdb
# the old database will be overwritten if exists
    $progname /data/blastdb
"
PrintHelp(){ #{{{
    echo "$usage"
}
#}}}
IsProgExist(){ #{{{
    # usage: IsProgExist prog
    # prog can be both with or without absolute path
    type -P $1 &>/dev/null \
        || { echo The program \'$1\' is required but not installed. \
        Aborting $0 >&2; exit 1; }
    return 0
}
#}}}
exec_cmd(){ #{{{
    local date=`date`
    echo "[$date] $*"
    eval "$*"
}

#}}}
if [ $# -ne 1 ]; then
    PrintHelp
    exit
fi

pfilt=$PSIPREDBIN/pfilt
IsProgExist wget
IsProgExist formatdb
IsProgExist gzip
IsProgExist readlink

if [ "$PSIPREDBIN" == "" ];then
    echo "env PSIPREDBIN is not set. Please set it as the path to the PSIPRED bin, where the program 'pfilt' is located" >&2
    exit 1
fi
IsProgExist $pfilt

isQuiet=0
outpath=$1


if [ ! -d $outpath ];then
    mkdir -p $outpath
fi

outpath=`readlink -f $outpath`

url=ftp://ftp.ebi.ac.uk/pub/databases/uniprot/uniref/uniref90/uniref90.fasta.gz
filename=uniref90.fasta.gz

tmpdir=$(mktemp -d $outpath/tmpdir.update_uniref90.XXXXXXXXX) || { echo "Failed to create temp dir" >&2; exit 1; }
trap 'rm -rf "$tmpdir"' INT TERM EXIT


cd $tmpdir

exec_cmd "wget $url -O $filename"
exec_cmd "gzip -dN $filename"
exec_cmd "formatdb -i uniref90.fasta -p T -o T"
exec_cmd "$pfilt uniref90.fasta > uniref90filt"
exec_cmd "formatdb -i uniref90filt -p T -o T"

SUCCESS=0
if [ -s uniref90.fasta.00.phr ] ;then
    SUCCESS=1
fi

if [ $SUCCESS -eq 1 ];then
    cd $outpath

    rm -f uniref90filt* uniref90.fasta uniref90.fasta*

    mv -f $tmpdir/uniref90.fasta* $outpath/
    mv -f $tmpdir/uniref90filt* $outpath/
fi

rm -rf $tmpdir
