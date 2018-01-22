#!/bin/bash

module load tacc-singularity
module load launcher

set -u

QUERY=""
OUT_DIR="$PWD/refseq-mash-out"
REFSEQ_MASH="/work/05066/imicrobe/iplantc.org/data/imicrobe/refseq-mash/refseq.genomes.k21s1000.msh"
IMG="refseq-mash-0.0.3.img"
MASH="singularity exec $IMG mash"

PARAMRUN="$TACC_LAUNCHER_DIR/paramrun"
export LAUNCHER_PLUGIN_DIR="$TACC_LAUNCHER_DIR/plugins"
export LAUNCHER_WORKDIR="$PWD"
export LAUNCHER_RMI=SLURM
export LAUNCHER_SCHED=interleaved

function lc() {
    wc -l "$1" | cut -d ' ' -f 1
}

function HELP() {
    printf "Usage:\n  %s -q QUERY [-o OUT_DIR]\n\n" "$(basename "$0")"

    echo "Required arguments:"
    echo " -q QUERY (dirs/files)"
    echo ""
    echo "Options:"
    echo " -o OUT_DIR ($OUT_DIR)"
    echo ""
    exit "${1:-0}"
}

[[ $# -eq 0 ]] && HELP 1

while getopts :o:q:h OPT; do
    case $OPT in
      h)
          HELP
          ;;
      o)
          OUT_DIR="$OPTARG"
          ;;
      q)
          QUERY="$QUERY $OPTARG"
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

#
# Check input, reference
#
INPUT_FILES=$(mktemp)
for QRY in $QUERY; do
    if [[ -d "$QRY" ]]; then
        find "$QRY" -type f >> "$INPUT_FILES"
    elif [[ -f "$QRY" ]]; then
        echo "$QRY" >> "$INPUT_FILES"
    else
        echo "\"$QRY\" neither file nor directory"
    fi
done

NUM_FILES=$(lc "$INPUT_FILES")

if [[ $NUM_FILES -lt 1 ]]; then
    echo "Found no usable files from QUERY \"$QUERY\""
    exit 1
fi

echo "Will process NUM_FILES \"$NUM_FILES\""
cat -n "$INPUT_FILES"

if [[ ! -f "$REFSEQ_MASH" ]]; then
    echo "REFSEQ_MASH \"$REFSEQ_MASH\" does not exist."
    exit 1
fi

#
# Set up
#
QUERY_SKETCH_DIR="$OUT_DIR/sketches"
DIST_DIR="$OUT_DIR/dist"
REPORTS_DIR="$OUT_DIR/reports"

for DIR in $QUERY_SKETCH_DIR $DIST_DIR $REPORTS_DIR; do
    [[ ! -d $DIR ]] && mkdir -p "$DIR"
done

#
# Sketch the input files, if necessary
#
ALL_QUERY="$OUT_DIR/all-query"
if [[ ! -s "$ALL_QUERY.msh" ]]; then
    echo "Sketching NUM_FILES \"$NUM_FILES\""
    PARAM="$$.param"
    cat /dev/null > "$PARAM"
  
    i=0
    while read -r FILE; do
        BASENAME=$(basename "$FILE")
        EXT=${BASENAME##*.}
        SKETCH_FILE="$QUERY_SKETCH_DIR/$BASENAME"

        if [[ -e "${SKETCH_FILE}.msh" ]]; then
            echo "SKETCH_FILE \"$SKETCH_FILE.msh\" exists already."
        elif [[ $EXT == "msh" ]]; then
            echo "$BASENAME looks like a Mash sketch"
            cp "$FILE" "$QUERY_SKETCH_DIR"
        else
            let i++
            printf "%3d: %s\n" $i "Sketching $BASENAME"
            echo "$MASH sketch -o $SKETCH_FILE $FILE" >> "$PARAM"
        fi
    done < "$INPUT_FILES"

    NUM_JOBS=$(lc "$PARAM")

    if [[ $NUM_JOBS -gt 0 ]]; then
        echo "Making ALL_QUERY \"$ALL_QUERY\" from $NUM_JOBS inputs"
        export LAUNCHER_JOB_FILE="$PARAM"
        if [[ $NUM_JOBS -lt 16 ]]; then
            export LAUNCHER_PPN=$NUM_JOBS
        else
            unset LAUNCHER_PPN
        fi
        $PARAMRUN
    else
        echo "There are no input file to sketch"
        exit 1
    fi
  
    QUERY_SKETCHES=$(mktemp)
    find "$QUERY_SKETCH_DIR" -name \*.msh > "$QUERY_SKETCHES"

    echo "Here are the sketches"
    cat -n "$QUERY_SKETCHES"

    NUM_SKETCHES=$(lc "$QUERY_SKETCHES")

    if [[ $NUM_SKETCHES -gt 0 ]]; then
        echo "Pasting NUM_SKETCHES \"$NUM_SKETCHES\" into ALL_QUERY \"$ALL_QUERY\""
        $MASH paste -l "$ALL_QUERY" "$QUERY_SKETCHES"
    else
        echo "There are no sketch files to paste"
        exit 1
    fi
  
    rm "$INPUT_FILES"
    rm "$QUERY_SKETCHES"
fi

MASH_DIST="$DIST_DIR/mash-dist.tab"
echo "Running distance for \"$ALL_QUERY\" vs \"$REFSEQ_MASH\""
$MASH dist -t "$ALL_QUERY.msh" "$REFSEQ_MASH" > "$MASH_DIST"

if [[ -f "$MASH_DIST" ]]; then
    echo "See MASH_DIST \"$MASH_DIST\""
else
    echo "Failed to create MASH_DIST \"$MASH_DIST\""
    exit 1
fi

echo "Comments to kyclark@email.arizona.edu"
