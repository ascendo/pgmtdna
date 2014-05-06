# Annotate and visualize the white spruce mitochondrial genome
# Copyright 2014 Shaun Jackman

name=pg29mt-concat

# Green plant mitochondria
edirect_query='Viridiplantae[Organism] mitochondrion[Title] (complete genome[Title] OR complete sequence[Title])'

all: $(name).gff $(name).evidence.gff $(name).repeat.gff $(name).gff.gene $(name).gbk.png

clean:
	rm -f $(name).gb $(name).gbk $(name).gff $(name).png

.PHONY: all clean
.DELETE_ON_ERROR:
.SECONDARY:

# Fetch data from NCBI

cds_na.orig.fa cds_aa.orig.fa: %.fa:
	esearch -db nuccore -query $(edirect_query) \
		|efetch -format fasta_$* \
		|sed -E 's/^>(.*gene=([^]]*).*)$$/>\2 \1/' >$@

cds_na.fa cds_aa.fa: %.fa: %.orig.fa
	seqmagick convert --pattern-exclude '^lcl|^orf|^ORF|^apt|^nd5|^ArthMp|hypothetical|putative|unnamed' $< $@

# RepeatModeler

%.nin: %.fa
	/usr/local/opt/repeatmodeler/BuildDatabase -name $* -engine ncbi $<

%.rm: %.nin
	RepeatModeler -database $*
	touch $@

RepeatModeler.fa: ThuApr31728402014/consensi.fa.classified
	cp -a $< $@

# MAKER

maker_bopts.ctl:
	maker -BOPTS

maker_exe.ctl:
	maker -EXE

rmlib.fa: PICEAGLAUCA_rpt2.0.fa RepeatModeler.fa
	cat $^ >$@

%.maker.output/stamp: maker_opts.ctl %.fa cds_na.fa cds_aa.fa rmlib.fa
	maker -fix_nucleotides -cpus 4
	touch $@

%.repeat.gff: %.maker.output/stamp
	cp `find $*.maker.output -name query.masked.gff` $@

%.evidence.orig.gff: %.maker.output/stamp
	gff3_merge -s -n -d $*.maker.output/$*_master_datastore_index.log >$@

%.orig.gff: %.maker.output/stamp
	gff3_merge -s -g -n -d $*.maker.output/$*_master_datastore_index.log >$@

%.gff: %.orig.gff
	sed -E 's/Name=trnascan-[^-]*-noncoding-([^-]*)-gene/Name=trn\1/g; \
		s/trnascan-[^-]*-processed-gene/trn/g; \
		s/-tRNA-1//g; \
		/rrn/s/mRNA/rRNA/; \
		/trn/s/mRNA/tRNA/' $< >$@

%.gb: %.gff %.fa
	bin/gff_to_genbank.py $^ >$@

%.gbk: %-header.gbk %.gb
	(cat $< && sed -n '/^FEATURES/,$${s/Name=/gene=/;s/-gene//;p;}' $*.gb) >$@

# OrganellarGenomeDRAW

%.gbk.png: %.gbk
	drawgenemap --format png --infile $< --outfile $<

# Report the annotated genes

%.gff.gene: %.gff
	bin/gff-gene-name $< >$@
