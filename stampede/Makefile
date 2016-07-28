clean:
	find . \( -name \*.conf -o -name \*.out -o -name \*.log -o -name \*.params -o -name launcher-\* \) -exec rm {} \;

dist: clean
	sbatch dist.sh

test: clean
	sbatch test.sh

update:
	apps-addupdate -F app.json

upload:
	files-upload -F $(WORK)/refseq-mash-0.0.1 kyclark/applications

file-upload:
	files-upload -F $(FILE) kyclark/applications/refseq-mash-0.0.1/stampede

eight:
	submit.sh $(SCRATCH)/gwatts/8of41strainisolates $(SCRATCH)/gwatts/refseq/8of41

23:
	submit.sh $(SCRATCH)/gwatts/23clinicalisolates $(SCRATCH)/gwatts/refseq/23clinicalisolates
