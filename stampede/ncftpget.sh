#!/bin/bash

#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 24:00:00
#SBATCH -p normal

echo Start $(date)
sh get-viral
echo End $(date)
