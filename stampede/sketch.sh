#!/bin/bash

#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 24:00:00
#SBATCH -p normal
#SBATCH -J sketch

function lc() {
  wc -l "$1" | cut -d ' ' -f 1
}

MASH="$WORK/mash-0.0.1/stampede/bin/mash"
REFSEQ_DIR="$SCRATCH/refseq"
GENOMES_DIR="$REFSEQ_DIR/genomes"
PARAMS=$$.params

for DIR in $(find $GENOMES_DIR -maxdepth 1 -mindepth 1 -type d); do
  OUT_DIR="$REFSEQ_DIR/mash/sketches/$(basename $DIR)"

  if [[ ! -d $OUT_DIR ]]; then
    mkdir -p "$OUT_DIR"
  fi

  FILES=$(mktemp)
  find "$DIR" -type f -name \*.gz > $FILES
  NUM_FILES=$(lc "$FILES")

  echo "NUM_FILES \"$NUM_FILES\" found in \"$DIR\""

  i=0
  cat $FILES | while read FILE; do
    let i++
    BASENAME=$(basename $FILE)
    SKETCH_PATH=$OUT_DIR/$BASENAME 

    if [[ ! -s $SKETCH_PATH ]]; then
      printf "%4d: %s\n" $i $BASENAME
      echo $MASH sketch -o "$SKETCH_PATH" "$FILE" >> $PARAMS
    fi
  done
done

module load launcher/2.0

export TACC_LAUNCHER_NPHI=0
export TACC_LAUNCHER_PPN=2
export EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
export WORKDIR=.
export TACC_LAUNCHER_SCHED=interleaved

echo Starting parallel job...
echo $(date)

EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher

time $TACC_LAUNCHER_DIR/paramrun SLURM $EXECUTABLE $WORKDIR $PARAMS

echo $(date)
echo Done
