#!/bin/bash

set -u

function lc() {
  wc -l "$1" | cut -d ' ' -f 1
}

function HELP() {
  printf "Usage:\n  %s -q QUERY -o OUT_DIR\n\n" $(basename $0)

  echo "Required arguments:"
  echo " -q QUERY (dir or file)"
  echo " -o OUT_DIR"
  echo ""
  exit 0
}

if [[ $# -eq 0 ]]; then
  HELP
fi

BIN=$( cd "$( dirname "$0" )" && pwd )

echo "----------"
echo "BIN \"$BIN\""
echo "Contents of $BIN"
ls -lh $BIN
echo "----------"

QUERY=""
OUT_DIR=$BIN

while getopts :o:q:h OPT; do
  case $OPT in
    h)
      HELP
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    q)
      QUERY="$OPTARG"
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument."
      exit 1
      ;;
    \?)
      echo "Error: Invalid option: -${OPTARG:-""}"
      exit 1
  esac
done

INPUT_FILES=$(mktemp)
if [[ -f $QUERY ]]; then
  echo $QUERY > $INPUT_FILES
elif [[ -d $QUERY ]]; then
  #
  # Convert BAM files to FASTA if necessary
  #
  BAM_FILES=$(mktemp)
  find "$QUERY" -name \*.bam > "$BAM_FILES"
  NUM_BAM=$(lc "$BAM_FILES")

  if [[ $NUM_BAM -gt 0 ]]; then
    while read BAM_FILE; do
      BASENAME=$(basename $BAM_FILE '.bam')
      FASTA="$QUERY/${BASENAME}.fa"

      if [[ ! -s $FASTA ]]; then
        echo "Converting BAM_FILE \"$BASENAME\""
        samtools fasta -0 "$FASTA" "$BAM_FILE"
      fi
    done < $BAM_FILES
  fi
  rm "$BAM_FILES"

  find "$QUERY" -type f -not -name \*.bam > "$INPUT_FILES"
else 
  echo "QUERY \"$QUERY\" is neither file nor directory"
  exit 1
fi

NUM_FILES=$(lc "$INPUT_FILES")

if [[ $NUM_FILES -lt 1 ]]; then
  echo "Found no usable files from QUERY \"$QUERY\""
  exit 1
fi

if [[ ! -d $OUT_DIR ]]; then
  mkdir -p "$OUT_DIR"
fi

DIST_DIR="$OUT_DIR/dist"
QUERY_SKETCH_DIR="$OUT_DIR/sketches"
REPORT_DIR="$OUT_DIR/reports"
REF_SKETCH_DIR="$SCRATCH/refseq/mash/sketches"
MASH="$WORK/bin/mash"

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

if [[ ! -d $REPORT_DIR ]]; then
  mkdir -p "$REPORT_DIR"
fi

#
# Sketch the input files, if necessary
#
ALL_QUERY="$OUT_DIR/all-$(basename $QUERY)"
if [[ ! -s ${ALL_QUERY}.msh ]]; then
  echo Sketching NUM_FILES \"$NUM_FILES\"

  while read FILE; do
    SKETCH_FILE="$QUERY_SKETCH_DIR/$(basename $FILE)"
    if [[ -e "${SKETCH_FILE}.msh" ]]; then
      echo SKETCH_FILE \"$SKETCH_FILE.msh\" exists already.
    else
      $MASH sketch -o "$SKETCH_FILE" "$FILE"
    fi
  done < $INPUT_FILES

  echo Making ALL_QUERY \"$ALL_QUERY\" 

  QUERY_SKETCHES=$(mktemp)
  find "$QUERY_SKETCH_DIR" -name \*.msh > "$QUERY_SKETCHES"
  $MASH paste -l "$ALL_QUERY" "$QUERY_SKETCHES"

  rm "$INPUT_FILES"
  rm "$QUERY_SKETCHES"
fi
ALL_QUERY=${ALL_QUERY}.msh

GENOME_DIRS=$(find $REF_SKETCH_DIR -mindepth 1 -maxdepth 1 -type d)
for GENOME in $GENOME_DIRS; do
  GENOME_DIR=$(basename $GENOME)

  #
  # The reference genomes ought to have been sketched already
  #
  ALL_REF="$(dirname $REF_SKETCH_DIR)/all-${GENOME_DIR}"

  if [[ ! -s "${ALL_REF}.msh" ]]; then
    MSH_FILES=$(mktemp)
    find "$REF_SKETCH_DIR/$GENOME_DIR" -type f -name \*.msh > $MSH_FILES
    NUM_MASH=$(lc "$MSH_FILES")

    if [[ $NUM_MASH -lt 1 ]]; then
      echo "Found no files in \"$REF_SKETCH_DIR/$GENOME_DIR\""
      continue
    fi

    echo "Pasting \"$NUM_MASH\" files to ALL_REF \"$ALL_REF\""
    $MASH paste -l "$ALL_REF" "$MSH_FILES"
    rm "$MSH_FILES"
  fi
  ALL_REF=${ALL_REF}.msh

  echo "DIST $(basename $ALL_QUERY) $(basename $ALL_REF)"
  $MASH dist -t "$ALL_QUERY" "$ALL_REF" > "${DIST_DIR}/${GENOME_DIR}.txt"
done

echo "Fixing dist output \"$DIST_DIR\""
./fix-dist.pl ${DIST_DIR}/*.txt

echo "Contents of \"$DIST_DIR\""
ls -l "$DIST_DIR"

echo "Creating reports"
./report-species.pl -o "$REPORT_DIR/strains" $DIST_DIR/*.fixed
./report-species.pl -s -o "$REPORT_DIR/species" $DIST_DIR/*.fixed
./report-species.pl -g -o "$REPORT_DIR/genus" $DIST_DIR/*.fixed

echo "Done, look in REPORT_DIR \"$REPORT_DIR\""

SLURM_FILE="slurm-${SLURM_JOB_ID}.out"
