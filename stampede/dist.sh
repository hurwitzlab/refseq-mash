#!/bin/bash

#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 2:00:00
#SBATCH -p development
#SBATCH -J dist

set -u

function lc() {
  wc -l $1 | cut -d ' ' -f 1
}

#IN_DIR=$WORK/reilly/rna
#OUT_DIR=$WORK/reilly/dist

IN_DIR=$SCRATCH/jimmy/fever/fasta
OUT_DIR=$SCRATCH/jimmy/fever/dist
MASH_DIR=$SCRATCH/refseq/mash
SKETCHES_DIR=$MASH_DIR/sketches
MASH=$WORK/mash-0.0.1/stampede/bin/mash

if [[ ! -d $IN_DIR ]]; then
  echo IN_DIR \"$IN_DIR\" does not exist.
  exit 1
fi

if [[ ! -d $OUT_DIR ]]; then
  mkdir -p $OUT_DIR
fi

#
# Sketch the input files, if necessary
#
ALL_QUERY="$(dirname $IN_DIR)/all-$(basename $IN_DIR)"
if [[ ! -s ${ALL_QUERY}.msh ]]; then
  FILES=$(mktemp)
  find $IN_DIR -type f > $FILES
  NUM_FILES=$(lc $FILES)

  if [[ $NUM_FILES -lt 1 ]]; then
    echo No files found in IN_DIR \"$IN_DIR\"
    exit 1
  fi

  echo Making ALL_QUERY \"$ALL_QUERY\" of NUM_FILES \"$NUM_FILES\"
  $MASH sketch -l -o $ALL_QUERY $FILES
  rm $FILES
fi
ALL_QUERY=${ALL_QUERY}.msh

for GENOME in $(ls $SKETCHES_DIR); do
  ALL_REF="${MASH_DIR}/all-${GENOME}"

  if [[ ! -s ${ALL_REF}.msh ]]; then
    MSH_FILES=$(mktemp)
    find $SKETCHES_DIR/$GENOME -type f -name \*.msh > $MSH_FILES
    NUM_MASH=$(lc $MSH_FILES)

    if [[ $NUM_MASH -lt 1 ]]; then
      echo Found no files in \"$SKETCHES_DIR/$GENOME\"
      continue
    fi

    echo Pasting \"$NUM_MASH\" files to ALL_REF \"$ALL_REF\"
    $MASH paste -l $ALL_REF $MSH_FILES
    rm $MSH_FILES
  fi
  ALL_REF=${ALL_REF}.msh

  echo DIST $(basename $ALL_QUERY) $(basename $ALL_REF)
  $MASH dist -t $ALL_QUERY $ALL_REF > ${OUT_DIR}/${GENOME}.txt
done

fix-dist.pl $OUT_DIR/*.txt

echo Done, look in OUT_DIR \"$OUT_DIR\"

# echo NUM_FILES \"$NUM_FILES\" found in \"$IN_DIR\"
# 
# PARAMS=$$.params
# 
# if [[ -e $PARAMS ]]; then
#   rm $PARAMS
# fi
# 
# i=0
# cat $FILES | while read FILE; do
#   let i++
#   BASENAME=$(basename $FILE)
#   printf "%4d: %s\n" $i $BASENAME
#   echo "$MASH dist -t $ALL_REF $FILE > $OUT_DIR/$BASENAME" >> $PARAMS
# done
# 
# module load launcher/2.0
# 
# export TACC_LAUNCHER_NPHI=0
# export TACC_LAUNCHER_PPN=2
# export EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
# export WORKDIR=.
# export TACC_LAUNCHER_SCHED=interleaved
# 
# echo Starting parallel job...
# echo $(date)
# 
# EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
# 
# time $TACC_LAUNCHER_DIR/paramrun SLURM $EXECUTABLE $WORKDIR $PARAMS
# 
# echo $(date)
# echo Done
