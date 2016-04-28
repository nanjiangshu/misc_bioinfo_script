#!/bin/bash

# Filename: update_swissprot.sh
# Description: update the swissprot database for PSIBLAST
# Author: Nanjiang Shu (nanjiang.shu@scilifelab.se)

progname=`basename $0`
size_progname=${#progname}
wspace=`printf "%*s" $size_progname ""` 
usage="
Usage:  $progname OUTPATH

Created 2016-04-28, updated 2016-04-28, Nanjiang Shu

Examples:
# update the swissprot blastdb at path /data/blastdb
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

IsProgExist wget
IsProgExist formatdb
IsProgExist gzip
IsProgExist readlink

isQuiet=0
outpath=$1


if [ ! -d $outpath ];then
    mkdir -p $outpath
fi

outpath=`readlink -f $outpath`

url=ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/swissprot.gz
filename=swissprot.gz

tmpdir=$(mktemp -d $outpath/tmpdir.update_swissprot.XXXXXXXXX) || { echo "Failed to create temp dir" >&2; exit 1; }
trap 'rm -rf "$tmpdir"' INT TERM EXIT


cd $tmpdir

exec_cmd "wget $url -O $filename"
exec_cmd "gzip -dN $filename"
exec_cmd "formatdb -i swissprot -p T -o T"

SUCCESS=0
if [ -s swissprot.phr -o -s swissprot.00.phr ] ;then
    SUCCESS=1
fi

if [ $SUCCESS -eq 1 ];then
    cd $outpath

    rm -f swissprot swissprot.*

    mv -f $tmpdir/swissprot* $outpath/
fi

rm -rf $tmpdir
