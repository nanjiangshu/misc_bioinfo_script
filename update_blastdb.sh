#!/bin/bash

# Description: update the swissprot database for PSIBLAST
# Author: Nanjiang Shu (nanjiang.shu@scilifelab.se)

dbname=swissprot
progname=`basename $0`
size_progname=${#progname}
wspace=`printf "%*s" $size_progname ""` 
usage="
Usage:  $progname DBNAME OUTPATH

Created 2016-04-28, 2019-01-10, Nanjiang Shu

DBNAME  DBNAME can be one of the swissprot, nr or uniref90

Examples:
# update the blastdb nr at path /data/blastdb
# the old database will be overwritten if exists
    $progname nr /data/blastdb
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
if [ $# -ne 2 ]; then
    PrintHelp
    exit
fi

IsProgExist wget
IsProgExist makeblastdb
IsProgExist gzip
IsProgExist readlink
IsProgExist curl

isQuiet=0
dbname=$1
outpath=$2

if [ ! -d $outpath ];then
    mkdir -p $outpath
fi

outpath=`readlink -f $outpath`

case $dbname in 
    swissprot|nr)
        url=ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/${dbname}.gz
        urlmd5=${url}.md5
        filename=${dbname}.gz
        md5filename=${dbname}.gz.md5
        ;;
    uniref90)
        pfilt=$PSIPREDBIN/pfilt
        if [ "$PSIPREDBIN" == "" ];then
            echo "Warning, env PSIPREDBIN is not set. Please set it as the path to the PSIPRED bin, where the program 'pfilt' is located" >&2
        fi
        dbname=${dbname}.fasta
        url=ftp://ftp.ebi.ac.uk/pub/databases/uniprot/uniref/uniref90/${dbname}.gz
        urlmeta=ftp://ftp.ebi.ac.uk/pub/databases/uniprot/uniref/uniref90/RELEASE.metalink
        filename=${dbname}.gz
        ;;
    *)
        echo "Wrong dbname $dbname. Exit" >&2
        exit 1
        ;;
esac

# check whether the database is up-to-date
IS_UP_TO_DATE=false

if [ -f "$outpath/$dbname" ];then
    date_local_db=$(stat -c  "%y" $outpath/$dbname | awk '{print $1}')
    date_remote_db=$(curl -I $url 2>/dev/null | grep Last-Mo | awk -F: '{print $2}')
    date_remote_db=$(/bin/date -d"$date_remote_db" +%Y-%m-%d)

    if [ "$date_remote_db" == "$date_local_db" -a "$date_remote_db" != "" ];then
        IS_UP_TO_DATE=true
    fi
fi

if [ "$IS_UP_TO_DATE" == "true" ];then
    echo "$dbname is already up to date to $date_remote_db"
    exit 0
fi

tmpdir=$(mktemp -d $outpath/tmpdir.update_${dbname}.XXXXXXXXX) || { echo "Failed to create temp dir" >&2; exit 1; }
trap 'rm -rf "$tmpdir"' INT TERM EXIT


cd $tmpdir

echo "Updating $dbname at $outpath..."

exec_cmd "wget -q $url -O $filename"

# integrity verification
md5_local=$(md5sum $filename | awk '{print $1}')
case $dbname in 
    swissprot|nr) md5_remote=$(curl -s $urlmd5 | awk '{print $1}') ;;
    uniref90*) md5_remote=$(curl -s $urlmeta | sed -n '/uniref90.fasta.gz/,$p' | sed -n '/hash/p' | head -n 1 | sed -e 's/<[^>]*>//g' | awk '{print $1}')
esac
if [ "$md5_local" == "$md5_remote" ]; then
    echo "md5 verification passed. Continue"
else
    echo "md5 verification failed. md5_local = $md5_local but md5_remote = $md5_remote. Stop."
fi


exec_cmd "gzip -dN $filename"
exec_cmd "makeblastdb -in $dbname -dbtype 'prot' -out $dbname -title $dbname -parse_seqids"


# For uniref90, create also the filtered database
case $dbname in 
    uniref90*)
        if [ "$PSIPREDBIN" != "" ];then
            exec_cmd "$pfilt ${dbname} > uniref90filt"
        fi
        dbnamefilt=uniref90filt
        exec_cmd "makeblastdb -in $dbnamefilt -dbtype 'prot' -out $dbnamefilt -title $dbnamefilt -parse_seqids"
        ;;
esac

SUCCESS=0
if [ -s ${dbname}.phr -o -s ${dbname}.00.phr ] ;then
    SUCCESS=1
fi

if [ $SUCCESS -eq 1 ];then
    cd $outpath

    rm -f $dbname ${dbname}.*

    mv -f $tmpdir/${dbname}* $outpath/
fi

rm -rf $tmpdir
