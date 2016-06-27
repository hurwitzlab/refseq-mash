#!/bin/bash

#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 02:00:00
#SBATCH -p development
#SBATCH -J refseq
#SBATCH --mail-type BEGIN,END,FAIL
#SBATCH --mail-user kyclark@email.arizona.edu

set -u

function lc() {
  wc -l "$1" | cut -d ' ' -f 1
}

#IN_DIR=$WORK/reilly/rna
#OUT_DIR=$WORK/reilly/dist

#IN_DIR=$SCRATCH/jimmy/fever/fasta
#OUT_DIR=$SCRATCH/jimmy/fever/dist

# QUERY_DIR="$SCRATCH/gazitua/fasta"
# OUT_DIR="$SCRATCH/gazitua/mash"

#QUERY_DIR="$WORK/delong/fasta"
#OUT_DIR="$SCRATCH/delong/mash"

#QUERY_DIR="$SCRATCH/data/jana/mock"
#OUT_DIR="$SCRATCH/data/jana/mash"

#QUERY_DIR="$SCRATCH/data/infant-gut/igm_2"
#OUT_DIR="$SCRATCH/data/infant-gut/mash"

BAM_DIR="$SCRATCH/gwatts/bug_mixing/wgs/bam"
QUERY_DIR="$SCRATCH/gwatts/bug_mixing/wgs/fasta"
OUT_DIR="$SCRATCH/gwatts/bug_mixing/wgs/mash"

if [[ -n $BAM_DIR ]] && [[ -d $BAM_DIR ]]; then
  if [[ ! -d $QUERY_DIR ]]; then
    mkdir -p "$QUERY_DIR"
  fi

  BAM_FILES=$(mktemp)
  find "$BAM_DIR" -name \*.bam > "$BAM_FILES"
  NUM_BAM=$(lc "$BAM_FILES")
  
  if [[ $NUM_BAM -lt 1 ]]; then
    echo No BAM files found in BAM_DIR \"$BAM_DIR\"
    exit 1
  fi

  while read BAM_FILE; do
    BASENAME=$(basename $BAM_FILE '.bam')
    FASTA="$QUERY_DIR/${BASENAME}.fa"
    if [[ ! -s $FASTA ]]; then
      echo Converting BAM_FILE \"$BASENAME\"
      samtools fasta -0 "$FASTA" "$BAM_FILE"
    fi
  done < $BAM_FILES
fi

DIST_DIR="$OUT_DIR/dist"
QUERY_SKETCH_DIR="$OUT_DIR/sketches"
MASH_DIR="$SCRATCH/refseq/mash"
REF_SKETCH_DIR="$MASH_DIR/sketches"
MASH="$WORK/mash-0.0.1/stampede/bin/mash"
WRAPPERDIR=$( cd "$( dirname "$0" )" && pwd )

if [[ ! -d $QUERY_DIR ]]; then
  echo QUERY_DIR \"$QUERY_DIR\" does not exist.
  exit 1
fi

if [[ ! -d $REF_SKETCH_DIR ]]; then
  echo REF_SKETCH_DIR \"$REF_SKETCH_DIR\" does not exist.
  exit 1
fi

if [[ ! -d $DIST_DIR ]]; then
  mkdir -p "$DIST_DIR"
fi

if [[ ! -d $QUERY_SKETCH_DIR ]]; then
  mkdir -p "$QUERY_SKETCH_DIR"
fi

#
# Sketch the input files, if necessary
#
ALL_QUERY="$OUT_DIR/all-$(basename $QUERY_DIR)"
if [[ ! -s ${ALL_QUERY}.msh ]]; then
  FILES=$(mktemp)
  #find $QUERY_DIR -type f -name \*QUALITY_PASSED\* > $FILES
  find "$QUERY_DIR" -type f > "$FILES"
  NUM_FILES=$(lc "$FILES")

  if [[ $NUM_FILES -lt 1 ]]; then
    echo No files found in QUERY_DIR \"$QUERY_DIR\"
    exit 1
  fi

  echo Sketching NUM_FILES \"$NUM_FILES\"
  while read FILE; do
    SKETCH_FILE="$QUERY_SKETCH_DIR/$(basename $FILE)"
    if [[ -e "${SKETCH_FILE}.msh" ]]; then
      echo SKETCH_FILE \"$SKETCH_FILE.msh\" exists already.
    else
      $MASH sketch -o "$SKETCH_FILE" "$FILE"
    fi
  done < $FILES

  echo Making ALL_QUERY \"$ALL_QUERY\" 

  QUERY_SKETCHES=$(mktemp)
  find "$QUERY_SKETCH_DIR" -name \*.msh > "$QUERY_SKETCHES"
  $MASH paste -l "$ALL_QUERY" "$QUERY_SKETCHES"

  rm "$FILES"
  rm "$QUERY_SKETCHES"
fi
ALL_QUERY=${ALL_QUERY}.msh

for GENOME in $(ls $REF_SKETCH_DIR); do
  ALL_REF="$(dirname $REF_SKETCH_DIR)/all-${GENOME}"

  if [[ ! -s "${ALL_REF}.msh" ]]; then
    MSH_FILES=$(mktemp)
    find "$REF_SKETCH_DIR/$GENOME" -type f -name \*.msh > $MSH_FILES
    NUM_MASH=$(lc $MSH_FILES)

    if [[ $NUM_MASH -lt 1 ]]; then
      echo "Found no files in \"$REF_SKETCH_DIR/$GENOME\""
      continue
    fi

    echo "Pasting \"$NUM_MASH\" files to ALL_REF \"$ALL_REF\""
    $MASH paste -l "$ALL_REF" "$MSH_FILES"
    rm "$MSH_FILES"
  fi
  ALL_REF=${ALL_REF}.msh

  echo DIST $(basename $ALL_QUERY) $(basename $ALL_REF)
  $MASH dist -t $ALL_QUERY $ALL_REF > ${DIST_DIR}/${GENOME}.txt
done

echo Fixing dist output from Mash
./fix-dist.pl $DIST_DIR/*.txt

REPORT_DIR="$OUT_DIR/species"

./report-species.pl -s -o "$REPORT_DIR" $DIST_DIR/*.fixed

echo Done, look in REPORT_DIR \""$REPORT_DIR"\"

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
