## Customize Makefile settings for mbao
##
## If you need to customize your Makefile, make
## changes here rather than in the main Makefile
#
# sh ./run.sh make clean
# sh ./run.sh make prepare_release
#
# MBA : 1
# DMBA : 17
# HBA : 10
# DHBA : 16
# PBA : 8

URIBASE = https://purl.brain-bican.org/ontology

JOBS = 16 # 1 17 10 8
#BRIDGES = aba dhba
BRIDGES = dhba
TARGETS = dhba

# linkml-owl and its dependencies are installed into PYDEPS by `dependencies`, apart from
# the ODK image's own Python packages, which they conflict with.
PYDEPS = $(TMPDIR)/pydeps
LINKML = env PYTHONPATH=$(PYDEPS) python3 $(PYDEPS)/bin/linkml-data2owl

STRUCTURE_GRAPHS = $(patsubst %, sources/%.json, $(JOBS))
ALL_GRAPH_ONTOLOGIES = $(patsubst sources/%.json,sources/%.ofn,$(STRUCTURE_GRAPHS))
ALL_BRIDGES = $(patsubst %, sources/uberon-bridge-to-%.owl, $(BRIDGES))
SOURCE_TEMPLATES = $(patsubst %, ../robot_templates/%_CCF_to_UBERON_source.tsv, $(TARGETS))
NEW_BRIDGES = $(patsubst %, new-bridges/new-uberon-bridge-to-%.owl, $(TARGETS))


# Rebuilt on every run unless COMP=false (as in QC: `make test COMP=false`), which uses
# the committed component. strip: `COMP=true # comment` in the Makefile leaves a space.
ifeq ($(strip $(COMP)),true)
.PHONY: $(COMPONENTSDIR)/all_templates.owl
$(COMPONENTSDIR)/all_templates.owl: clean_files dependencies $(COMPONENTSDIR)/linkouts.owl $(COMPONENTSDIR)/sources_merged.owl
	$(ROBOT) merge -i $(COMPONENTSDIR)/linkouts.owl -i $(COMPONENTSDIR)/sources_merged.owl annotate --ontology-iri $(URIBASE)/$@ convert -f ofn -o $@
endif
.PRECIOUS: $(COMPONENTSDIR)/all_templates.owl

# Installing depedencies so it can run in ODK container
.PHONY: dependencies
dependencies:
	pip3 install -q --ignore-installed --target $(PYDEPS) -r ../../requirements.txt -c ../../constraints.txt


LOCAL_CLEAN_FILES = $(ALL_GRAPH_ONTOLOGIES) $(ALL_BRIDGES) $(TMPDIR)/tmp.json $(TMPDIR)/tmp.owl $(COMPONENTSDIR)/sources_merged.owl $(COMPONENTSDIR)/linkouts.owl $(TEMPLATEDIR)/linkouts.tsv

# clean previous build files
.PHONY: clean_files
clean_files:
	rm -f $(LOCAL_CLEAN_FILES)

sources/%.json:
	curl -o $@ $(subst %,$(subst sources/,,$@),"http://api.brain-map.org/api/v2/structure_graph_download/%")

../linkml/data/template_%.tsv: sources/%.json
	python3 $(SCRIPTSDIR)/structure_graph_template.py -i $< -o $@
.PRECIOUS: ../linkml/data/template_%.tsv:
# TODO delete

sources/%.ofn: ../linkml/data/template_%.tsv
	$(LINKML) -C Class -s ../linkml/structure_graph_schema.yaml $< -o $@
.PRECIOUS: sources/%.ofn

# download bridges
#sources/uberon-bridge-to-aba.owl:
#	curl -o sources/uberon-bridge-to-aba.obo "https://raw.githubusercontent.com/obophenotype/uberon/master/src/ontology/bridge/uberon-bridge-to-aba.obo"
#	$(ROBOT) convert -i sources/uberon-bridge-to-aba.obo --format owl -o $@
#	sed -i 's|http://purl.obolibrary.org/obo/ABA_|https://purl.brain-bican.org/ontology/abao/ABA_|g' $@

# From the pinned Uberon release (UBERON_RELEASE), so that the bridge, the import and the
# full-Uberon QC all use the same Uberon. Uberon regenerates the bridge at each release.
sources/uberon-bridge-to-dhba.owl:
	curl -fsSL -o sources/uberon-bridge-to-dhba.owl "https://raw.githubusercontent.com/obophenotype/uberon/v$(UBERON_RELEASE)/src/ontology/bridge/uberon-bridge-to-dhba.owl"
	$(ROBOT) convert -i sources/uberon-bridge-to-dhba.owl --format owl -o $@
	sed -i 's|http://purl.obolibrary.org/obo/DHBA_|https://purl.brain-bican.org/ontology/dhbao/DHBA_|g' $@

sources/uberon-bridge-to-dmba.owl:
	curl -o sources/uberon-bridge-to-dmba.owl "https://raw.githubusercontent.com/obophenotype/uberon/master/src/ontology/bridge/uberon-bridge-to-dmba.owl"
	$(ROBOT) convert -i sources/uberon-bridge-to-dmba.owl --format owl -o $@
	sed -i 's|http://purl.obolibrary.org/obo/DMBA_|https://purl.brain-bican.org/ontology/dmbao/DMBA_|g' $@

sources/uberon-bridge-to-hba.owl:
	curl -o sources/uberon-bridge-to-hba.owl "https://raw.githubusercontent.com/obophenotype/uberon/master/src/ontology/bridge/uberon-bridge-to-hba.owl"
	$(ROBOT) convert -i sources/uberon-bridge-to-hba.owl --format owl -o $@
	sed -i 's|http://purl.obolibrary.org/obo/HBA_|https://purl.brain-bican.org/ontology/hbao/HBA_|g' $@

sources/uberon-bridge-to-mba.owl:
	curl -o sources/uberon-bridge-to-mba.owl "https://raw.githubusercontent.com/obophenotype/uberon/master/src/ontology/bridge/uberon-bridge-to-mba.owl"
	$(ROBOT) convert -i sources/uberon-bridge-to-mba.owl --format owl -o $@
	sed -i 's|http://purl.obolibrary.org/obo/MBA_|https://purl.brain-bican.org/ontology/mbao/MBA_|g' $@

sources/uberon-bridge-to-pba.owl:
	curl -o sources/uberon-bridge-to-pba.owl "https://raw.githubusercontent.com/obophenotype/uberon/master/src/ontology/bridge/uberon-bridge-to-pba.owl"
	$(ROBOT) convert -i sources/uberon-bridge-to-pba.owl --format owl -o $@
	sed -i 's|http://purl.obolibrary.org/obo/PBA_|https://purl.brain-bican.org/ontology/pbao/PBA_|g' $@

# TODO handle legacy mapings

#all_bridges:
#	make sources/uberon-bridge-to-aba.obo sources/uberon-bridge-to-dmba.obo -B

# Merge sources. # crudely listing dependencies for now - but could switch to using pattern expansion
#sources_merged.owl: all_bridges
#	robot merge --input sources/1.ofn --input sources/17.ofn --input sources/10.ofn --input sources/16.ofn --input sources/8.ofn --input sources/uberon-bridge-to-aba.obo --input sources/uberon-bridge-to-dhba.obo --input sources/uberon-bridge-to-dmba.obo --input sources/uberon-bridge-to-hba.obo --input sources/uberon-bridge-to-mba.obo --input sources/uberon-bridge-to-pba.obo annotate --ontology-iri $(URIBASE)/$@ -o $@

$(COMPONENTSDIR)/sources_merged.owl: $(ALL_GRAPH_ONTOLOGIES) $(ALL_BRIDGES)
	$(ROBOT) merge $(patsubst %, -i %, $^) relax annotate --ontology-iri $(URIBASE)/$@ -o $@

# merge uberon + sources, reason & relax (EC -> SC)
$(TMPDIR)/tmp.owl: $(SRC) $(COMPONENTSDIR)/sources_merged.owl
	robot merge $(patsubst %, -i %, $^) relax annotate --ontology-iri $(URIBASE)/$@ -o $@

# Make a json file for use in generating ROBOT template
$(TMPDIR)/tmp.json: $(TMPDIR)/tmp.owl
	$(ROBOT) convert --input $< -f json -o $@

# Build robot  template - with linkouts and prefLabels
$(TEMPLATEDIR)/linkouts.tsv: $(TMPDIR)/tmp.json
	python $(SCRIPTSDIR)/gen_linkout_template.py $<

# generate OWL from template
$(COMPONENTSDIR)/linkouts.owl: $(TMPDIR)/tmp.owl $(TEMPLATEDIR)/linkouts.tsv
	$(ROBOT) template --template $(word 2, $^) --input $< --add-prefixes template_prefixes.json -o $@




# Uberon release used both for the Uberon import (mirror-uberon below) and for the full-Uberon
# QC (reason_test_uberon). Pinned so that a new Uberon release can't change the import or fail
# a PR on its own. Bump it before `make refresh-imports`, then regenerate UBERON_QC_KNOWN with
# `make reason_test_uberon UBERON_QC_UPDATE=true`. See docs/uberon-qc.md.
UBERON_RELEASE = 2026-11-05
UBERON_RELEASE_URL = https://github.com/obophenotype/uberon/releases/download/v$(UBERON_RELEASE)

## ONTOLOGY: uberon (remove disjoint classes and properties, they are causing inconsistencies when merged with dhba bridge)
## Overrides the generated rule, which mirrors the unversioned uberon-base.owl PURL (latest release).
.PHONY: mirror-uberon
.PRECIOUS: $(MIRRORDIR)/uberon.owl
mirror-uberon: | $(TMPDIR)
	if [ $(MIR) = true ] && [ $(IMP) = true ]; then curl -L $(UBERON_RELEASE_URL)/uberon-base.owl --create-dirs -o $(MIRRORDIR)/uberon.owl --retry 4 --max-time 200 &&\
		$(ROBOT) convert -i $(MIRRORDIR)/uberon.owl -o $@.tmp.owl && \
		$(ROBOT) remove -i $@.tmp.owl --axioms disjoint -o $@.tmp.owl && \
		mv $@.tmp.owl $(TMPDIR)/$@.owl; fi
#	if [ $(MIR) = true ] && [ $(IMP) = true ]; then $(ROBOT) convert -I http://purl.obolibrary.org/obo/uberon/subsets/human-view.owl -o $@.tmp.owl &&\
#		$(ROBOT) remove -i $@.tmp.owl --axioms disjoint -o $@.tmp.owl && \
#		mv $@.tmp.owl $(TMPDIR)/$@.owl; fi


## Disable '--equivalent-classes-allowed asserted-only' due to DHBA inconsistencies
.PHONY: reason_test
reason_test: $(EDIT_PREPROCESSED)
	# $(ROBOT) explain --input $< --reasoner ELK -M unsatisfiability --unsatisfiable all --explanation explanation.md
	# $(ROBOT) reason --input $< --reasoner ELK --equivalent-classes-allowed asserted-only \
	# 	--exclude-tautologies structural --output test.owl && rm test.owl
	$(ROBOT) reason --input $< --reasoner ELK \
		--exclude-tautologies structural --output test.owl && rm test.owl

## Disable '--equivalent-classes-allowed asserted-only' due to DHBA inconsistencies
# Full: The full artefacts with imports merged, reasoned.
$(ONT)-full.owl: $(EDIT_PREPROCESSED) $(OTHER_SRC) $(IMPORT_FILES)
	$(ROBOT_RELEASE_IMPORT_MODE) \
		reason --reasoner ELK --exclude-tautologies structural \
		relax \
		reduce -r ELK \
		$(SHARED_ROBOT_COMMANDS) annotate --ontology-iri $(ONTBASE)/$@ $(ANNOTATE_ONTOLOGY_VERSION) --output $@.tmp.owl && mv $@.tmp.owl $@

## Disable '--equivalent-classes-allowed asserted-only' due to DHBA inconsistencies
# foo-simple: (edit->reason,relax,reduce,drop imports, drop every axiom which contains an entity outside the "namespaces of interest")
# drop every axiom: filter --term-file keep_terms.txt --trim true
#	remove --select imports --trim false
$(ONT)-simple.owl: $(EDIT_PREPROCESSED) $(OTHER_SRC) $(SIMPLESEED) $(IMPORT_FILES)
	$(ROBOT_RELEASE_IMPORT_MODE) \
		reason --reasoner ELK --exclude-tautologies structural \
		relax \
		remove --axioms equivalent \
		relax \
		filter --term-file $(SIMPLESEED) --select "annotations ontology anonymous self" --trim true --signature true \
		reduce -r ELK \
		query --update ../sparql/inject-subset-declaration.ru --update ../sparql/inject-synonymtype-declaration.ru \
		$(SHARED_ROBOT_COMMANDS) annotate --ontology-iri $(ONTBASE)/$@ $(ANNOTATE_ONTOLOGY_VERSION) --output $@.tmp.owl && mv $@.tmp.owl $@

#	Overwrite the default rule to use ONTBASE instead of URIBASE
$(ONT).owl: $(ONT)-full.owl
	$(ROBOT) annotate --input $< --ontology-iri $(ONTBASE)/$@ $(ANNOTATE_ONTOLOGY_VERSION) \
		convert -o $@.tmp.owl && mv $@.tmp.owl $@
$(ONT).json: $(ONT).owl
	$(ROBOT) annotate --input $< --ontology-iri $(ONTBASE)/$@ $(ANNOTATE_ONTOLOGY_VERSION) \
		convert --check false -f json -o $@.tmp.json &&\
		mv $@.tmp.json $@

# QC: reason over DHBA with the full Uberon release (UBERON_RELEASE), including the disjointness
# axioms that mirror-uberon strips from the import. This is what CL's release sees. Two kinds of
# inconsistency are checked:
#   - unsatisfiable classes, e.g. a DHBA structure placed under a parent whose Uberon mapping is a
#     region that Uberon says the structure is not in;
#   - inferred equivalences between named classes, e.g. two DHBA classes mapped to the same Uberon
#     class (obophenotype/uberon#3815), which fail CL's `--equivalent-classes-allowed asserted-only`.
# Known ones are listed in UBERON_QC_KNOWN: one IRI per unsatisfiable class, `IRI == IRI` per
# equivalence (IRIs in sorted order). The check fails on anything not in the list, on a listed line that no longer
# applies (remove it from the list), or if the list was generated for another Uberon release.
# Run in CI.
#   make reason_test_uberon UBERON_QC_UPDATE=true   rewrites UBERON_QC_KNOWN and prints what changed
UBERON_QC = $(TMPDIR)/uberon-$(UBERON_RELEASE).owl
UBERON_QC_KNOWN = qc_known_inconsistent_full_uberon.txt
UBERON_QC_UPDATE = false

.PRECIOUS: $(UBERON_QC)
$(UBERON_QC): | $(TMPDIR)
	curl -fsSL --retry 3 -o $@.tmp $(UBERON_RELEASE_URL)/uberon.owl && mv $@.tmp $@

# Unsatisfiable classes stop ROBOT before it reports equivalences, and every unsatisfiable class
# is equivalent to owl:Nothing, so equivalences are found in a second pass without disjointness.
.PHONY: reason_test_uberon
reason_test_uberon: $(EDIT_PREPROCESSED) $(UBERON_QC) | $(TMPDIR)
	$(ROBOT) merge -i $< -i $(UBERON_QC) -o $(TMPDIR)/$@-merged.ofn && \
	$(ROBOT) reason -i $(TMPDIR)/$@-merged.ofn --reasoner ELK --equivalent-classes-allowed all \
		-o $(TMPDIR)/$@.owl > $(TMPDIR)/$@.log 2>&1; status=$$?; \
	grep -oE 'unsatisfiable: [^ ]+' $(TMPDIR)/$@.log | cut -d' ' -f2 > $(TMPDIR)/$@.unsat; \
	if [ $$status -ne 0 ] && [ ! -s $(TMPDIR)/$@.unsat ]; then cat $(TMPDIR)/$@.log; exit 1; fi; \
	$(ROBOT) remove -i $(TMPDIR)/$@-merged.ofn --axioms disjoint \
		reason --reasoner ELK --equivalent-classes-allowed asserted-only \
		-o $(TMPDIR)/$@.owl > $(TMPDIR)/$@-eq.log 2>&1; status=$$?; \
	grep 'Equivalence: ' $(TMPDIR)/$@-eq.log | sed 's/.*Equivalence: //; s/[<>]//g' \
		| awk '{ if ($$1 > $$3) print $$3 " == " $$1; else print $$1 " == " $$3 }' > $(TMPDIR)/$@.equiv; \
	if [ $$status -ne 0 ] && [ ! -s $(TMPDIR)/$@.equiv ]; then cat $(TMPDIR)/$@-eq.log; exit 1; fi; \
	cat $(TMPDIR)/$@.unsat $(TMPDIR)/$@.equiv | LC_ALL=C sort -u > $(TMPDIR)/$@.txt; \
	grep -v '^#' $(UBERON_QC_KNOWN) | LC_ALL=C sort -u > $(TMPDIR)/$@.known; \
	fixed=$$(LC_ALL=C comm -23 $(TMPDIR)/$@.known $(TMPDIR)/$@.txt); \
	new=$$(LC_ALL=C comm -13 $(TMPDIR)/$@.known $(TMPDIR)/$@.txt); \
	if [ $(UBERON_QC_UPDATE) = true ]; then \
		{ echo "# DHBA inconsistencies with Uberon v$(UBERON_RELEASE) ($(UBERON_RELEASE_URL)/uberon.owl)"; \
		  echo "# One unsatisfiable class per line, or 'IRI == IRI' for an inferred equivalence."; \
		  echo "# Generated by: make reason_test_uberon UBERON_QC_UPDATE=true. Only remove lines by hand. See docs/uberon-qc.md"; \
		  cat $(TMPDIR)/$@.txt; } > $(UBERON_QC_KNOWN); \
		echo "Removed from $(UBERON_QC_KNOWN) (no longer inconsistent): $$(printf '%s' "$$fixed" | grep -c .)"; \
		if [ -n "$$fixed" ]; then echo "$$fixed"; fi; \
		echo "Added to $(UBERON_QC_KNOWN) (new, explain each before committing): $$(printf '%s' "$$new" | grep -c .)"; \
		if [ -n "$$new" ]; then echo "$$new"; fi; \
		echo "Wrote $$(wc -l < $(TMPDIR)/$@.txt | tr -d ' ') lines to $(UBERON_QC_KNOWN)"; exit 0; fi; \
	fail=0; \
	if ! head -1 $(UBERON_QC_KNOWN) | grep -qF "Uberon v$(UBERON_RELEASE) "; then \
		echo "$(UBERON_QC_KNOWN) was not generated for UBERON_RELEASE=$(UBERON_RELEASE)."; \
		echo "Regenerate it: make reason_test_uberon UBERON_QC_UPDATE=true"; fail=1; fi; \
	if [ -n "$$fixed" ]; then echo "No longer inconsistent, remove from $(UBERON_QC_KNOWN):"; echo "$$fixed"; fail=1; fi; \
	if [ -n "$$new" ]; then echo "NEW unsatisfiable classes or inferred equivalences with full Uberon:"; echo "$$new"; \
		echo "Explain with: robot merge -i dhbao-edit.owl -i $(UBERON_QC) explain -M unsatisfiability --unsatisfiable all --explanation explain.md"; fail=1; fi; \
	if [ $$fail -ne 0 ]; then exit 1; fi; \
	echo "No new inconsistencies ($$(wc -l < $(TMPDIR)/$@.txt | tr -d ' ') known ones remain, all listed in $(UBERON_QC_KNOWN))"
