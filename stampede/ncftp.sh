#!/bin/bash

#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 24:00:00
#SBATCH -p normal

CWD=$(pwd)
GENOMES=genomes
i=0
for DIR in $(ls $GENOMES); do
  echo $GENOMES/$DIR
  cd $GENOMES/$DIR
  cat ftpfilepaths | while read FTP; do
    BASENAME=$(basename $FTP)
    if [[ ! -s $BASENAME ]]; then
      let i++
      printf "%4d: %s\n" $i $BASENAME
      #ncftpget $FTP
    fi
  done
  cd $CWD
done

echo Done, downloaded $i genomes.
