APP_ID = "refseq-mash-0.0.3"

clean:
	find . \( -name \*.out -o -name \*.param \) -exec rm {} \;

test: clean
	sbatch test.sh

app:
	apps-addupdate -F app.json

up:
	copy_from_manifest.py

eight:
	submit.sh $(SCRATCH)/gwatts/8of41strainisolates $(SCRATCH)/gwatts/refseq/8of41

23:
	submit.sh $(SCRATCH)/gwatts/23clinicalisolates $(SCRATCH)/gwatts/refseq/23clinicalisolates

jimmy: clean
	submit.sh $(SCRATCH)/jimmy/fever/fasta $(SCRATCH)/jimmy/fever/refseq-mash

george: clean
	submit.sh $(SCRATCH)/george/p3/fasta $(SCRATCH)/george/p3/refseq-mash
