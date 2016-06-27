clean:
	find . \( -name \*.conf -o -name \*.out -o -name \*.log -o -name \*.params -o -name launcher-\* \) -exec rm {} \;

dist: clean
	sbatch dist.sh

test: clean
	sbatch test.sh
