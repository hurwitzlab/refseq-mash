#!/bin/bash

if [[ $# -lt 2 ]]; then
  printf "Usage: %s QUERY_DIR OUT_DIR\n" $(basename $0)
  exit 1
fi

sbatch -A iPlant-Collabs -N 1 -n 1 -t 24:00:00 -p normal -J refseq --mail-type BEGIN,END,FAIL --mail-user kyclark@email.arizona.edu run.sh -q $1 -o $2
