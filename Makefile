OBO= http://purl.obolibrary.org/obo
CAT= --catalog-xml ../catalog-v001.xml

# ----------------------------------------
# CAUSAL PHENOTYPE NETWORKS
# ----------------------------------------
gen-%.obo: phenomaker.pro
	blip-findall  -consult $< -r go -r pato -r pext -r cell -r chebi -r nbo -r mpath "wall($*)" > $@.tmp && owltools $@.tmp footer.obo --merge-support-ontologies -o -f obo $@ && grep -c ^id: $@
###	blip-findall -debug index -index "ontol_db:subclassT(+,+)"  -consult $< -r go -r pato -r pext -r cell -r chebi -r nbo "wall($*)" > $@.tmp && owltools $@.tmp footer.obo --merge-support-ontologies -o -f obo $@ && grep -c ^id: $@


CORE_BUNDLE = uberon/ext go/extensions/go-plus pato
CORE_IMPORT = $(OBO)/cpn/imports.owl
imports.owl:
	owltools $(CAT) $(patsubst %, $(OBO)/%.owl, $(CORE_BUNDLE)) --merge-support-ontologies --merge-imports-closure --make-subset-by-properties -f $(KEEPRELS) --remove-axiom-annotations --remove-annotation-assertions -l --remove-axioms -t DisjointClasses --set-ontology-id $(CORE_IMPORT) -o $@

# sneak in bridging axioms here
core.obo: phenomaker.pro cpn-axioms.obo
	owltools gen-*.obo cpn-axioms.obo --merge-support-ontologies --set-ontology-id $(OBO)/core.owl -o -f obo $@

core.owl: core.obo
	owltools $< -o $@

import_module.owl: core.obo imports.owl
	owltools $^ --extract-module -s $(CORE_IMPORT) -c --set-ontology-id $(OBO)/$@ -o $@

import_module.obo: import_module.owl
	owltools $< -o -f obo --no-check $@

core-merged.owl: core.obo import_module.owl
	owltools $^ --merge-support-ontologies -o $@

# add imports for owl version
unreasoned.owl: core.obo import_module.owl
#	owltools $^ --add-imports-from-supports -o $@
	owltools $^ --merge-support-ontologies --set-ontology-id $(OBO)/cpn/unreasoned.owl -o $@

# reasoned version
cpn.obo: core.obo import_module.owl
	owltools $^ --add-imports-from-supports --assert-inferred-subclass-axioms -o -f obo --no-check $@


## for comparison

%-cpn-inf.obo: %-nsc.owl unreasoned.owl
	owltools $(CAT) $^ --add-imports-from-supports --assert-inferred-subclass-axioms --allowEquivalencies -o -f obo --no-check $@.tmp && grep -v ^owl-axioms $@.tmp > $@

all-inf.obo: ../mp/mp-nsc.owl ../hp/hp-nsc.owl ../fypo/fypo-nsc.owl 
	owltools $(CAT) $^ --merge-support-ontologies unreasoned.owl --add-imports-from-supports --assert-inferred-subclass-axioms --allowEquivalencies -o -f obo --no-check $@.tmp && grep -v ^owl-axioms $@.tmp > $@

ARTEFACTS= core.obo core.owl unreasoned.owl cpn.obo *-cpn-inf.obo
deploy:
	rsync -avz $(ARTEFACTS) yuri.lbl.gov:public_html/cpn/
