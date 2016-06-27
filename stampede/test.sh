#!/bin/bash

#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 02:00:00
#SBATCH -p development
#SBATCH -J refseq
#SBATCH --mail-type BEGIN,END,FAIL
#SBATCH --mail-user kyclark@email.arizona.edu

run.sh -q "$SCRATCH/gazitua/fasta" -o "$SCRATCH/gazitua/refseq"
