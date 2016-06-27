#!/bin/bash

set -u

QUERY_DIR=""
OUT_DIR=""

function lc() {
  wc -l "$1" | cut -d ' ' -f 1
}

function HELP() {
  printf "Usage:\n  %s -q QUERY_DIR -o OUT_DIR\n\n" $(basename $0)

  echo "Required arguments:"
  echo " -q QUERY_DIR"
  echo " -o OUT_DIR"
  echo ""
  exit 0
}

if [[ $# -eq 0 ]]; then
  HELP
fi

while getopts :o:q:h OPT; do
  case $OPT in
    h)
      HELP
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    q)
      QUERY_DIR="$OPTARG"
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

if [[ ! -d $QUERY_DIR ]]; then
  echo QUERY_DIR \"$QUERY_DIR\" does not exist.
  exit 1
fi

if [[ ! -d $OUT_DIR ]]; then
  mkdir -p "$OUT_DIR"
fi

#
# Convert BAM files to FASTA if necessary
#
BAM_FILES=$(mktemp)
find "$QUERY_DIR" -name \*.bam > "$BAM_FILES"
NUM_BAM=$(lc "$BAM_FILES")

if [[ $NUM_BAM -gt 0 ]]; then
  while read BAM_FILE; do
    BASENAME=$(basename $BAM_FILE '.bam')
    FASTA="$QUERY_DIR/${BASENAME}.fa"

    if [[ ! -s $FASTA ]]; then
      echo "Converting BAM_FILE \"$BASENAME\""
      samtools fasta -0 "$FASTA" "$BAM_FILE"
    fi
  done < $BAM_FILES
fi
rm "$BAM_FILES"

DIST_DIR="$OUT_DIR/dist"
QUERY_SKETCH_DIR="$OUT_DIR/sketches"
MASH_DIR="$SCRATCH/refseq/mash"
REF_SKETCH_DIR="$MASH_DIR/sketches"
MASH="$WORK/bin/mash"
WRAPPERDIR=$( cd "$( dirname "$0" )" && pwd )

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
  find "$QUERY_DIR" -type f -not -name \*.bam > "$FILES"
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
  #
  # The reference genomes ought to have been sketched already
  #
  ALL_REF="$(dirname $REF_SKETCH_DIR)/all-${GENOME}"

  if [[ ! -s "${ALL_REF}.msh" ]]; then
    MSH_FILES=$(mktemp)
    find "$REF_SKETCH_DIR/$GENOME" -type f -name \*.msh > $MSH_FILES
    NUM_MASH=$(lc "$MSH_FILES")

    if [[ $NUM_MASH -lt 1 ]]; then
      echo "Found no files in \"$REF_SKETCH_DIR/$GENOME\""
      continue
    fi

    echo "Pasting \"$NUM_MASH\" files to ALL_REF \"$ALL_REF\""
    $MASH paste -l "$ALL_REF" "$MSH_FILES"
    rm "$MSH_FILES"
  fi
  ALL_REF=${ALL_REF}.msh

  echo "DIST $(basename $ALL_QUERY) $(basename $ALL_REF)"
  $MASH dist -t "$ALL_QUERY" "$ALL_REF" > "${DIST_DIR}/${GENOME}.txt"
done

echo "Fixing dist output from Mash"
./fix-dist.pl "$DIST_DIR/*.txt"

REPORT_DIR="$OUT_DIR/species"

./report-species.pl -s -o "$REPORT_DIR" "$DIST_DIR/*.fixed"

echo "Done, look in REPORT_DIR \"$REPORT_DIR\""
