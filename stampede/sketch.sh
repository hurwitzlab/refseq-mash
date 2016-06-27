#!/bin/bash

#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 2:00:00
#SBATCH -p development
#SBATCH -J sketch

function lc() {
  wc -l "$1" | cut -d ' ' -f 1
}

MASH="$WORK/mash-0.0.1/stampede/bin/mash"
REFSEQ_DIR="$SCRATCH/refseq"
GENOMES_DIR="$REFSEQ_DIR/genomes"

for DIR in $(ls $GENOMES_DIR); do
  IN_DIR="$GENOMES_DIR/$DIR"
  OUT_DIR="$REFSEQ_DIR/mash/sketches/$DIR"

  if [[ ! -d $OUT_DIR ]]; then
    mkdir -p "$OUT_DIR"
  fi

  FILES=$(mktemp)
  find "$IN_DIR" -type f -name \*.gz > $FILES
  NUM_FILES=$(lc "$FILES")

  echo "NUM_FILES \"$NUM_FILES\" found in \"$IN_DIR\""

  i=0
  cat $FILES | while read FILE; do
    let i++
    BASENAME=$(basename $FILE)
    SKETCH_PATH=$OUT_DIR/$BASENAME 

    if [[ ! -s $SKETCH_PATH ]]; then
      printf "%4d: %s\n" $i $BASENAME
      $MASH sketch -o "$SKETCH_PATH" "$FILE"
    fi
  done
done

echo Done
