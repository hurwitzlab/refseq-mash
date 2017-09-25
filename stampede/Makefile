APP_ID = "refseq-mash-0.0.2"

clean:
	find . \( -name \*.conf -o -name \*.out -o -name \*.log -o -name \*.params -o -name launcher-\* \) -exec rm {} \;

dist: clean
	sbatch dist.sh

test: clean
	sbatch test.sh

update:
	apps-addupdate -F app.json

upload:
	files-upload -F $(WORK)/$(APP_ID) kyclark/applications

file-upload:
	files-upload -F $(FILE) kyclark/applications/$(APP_ID)/stampede

eight:
	submit.sh $(SCRATCH)/gwatts/8of41strainisolates $(SCRATCH)/gwatts/refseq/8of41

23:
	submit.sh $(SCRATCH)/gwatts/23clinicalisolates $(SCRATCH)/gwatts/refseq/23clinicalisolates

jimmy: clean
	submit.sh $(SCRATCH)/jimmy/fever/fasta $(SCRATCH)/jimmy/fever/refseq-mash

george: clean
	submit.sh $(SCRATCH)/george/p3/fasta $(SCRATCH)/george/p3/refseq-mash
