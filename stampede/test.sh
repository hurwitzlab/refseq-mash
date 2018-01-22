#!/bin/bash

#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 02:00:00
#SBATCH -p development
#SBATCH -J refseq
#SBATCH --mail-type BEGIN,END,FAIL
#SBATCH --mail-user kyclark@email.arizona.edu

#run.sh -q "$SCRATCH/gazitua/fasta" -o "$SCRATCH/gazitua/refseq"
#run.sh -q "$WORK/data/dolphin/fasta"

run.sh -q $WORK/data/dolphin/fasta/Dolphin_1_z04.fa -q $WORK/data/dolphin/fasta/Dolphin_8_z26.fa
