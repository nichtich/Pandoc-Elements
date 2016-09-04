EXAMPLES = $(basename $(wildcard *-sample.md))
ALLPDF = $(addsuffix .pdf,$(EXAMPLES))
ALLHTML = $(addsuffix .html,$(EXAMPLES))

PANDOC_VERSION=$(shell pandoc --version | perl -E '<> =~ /pandoc (\d+\.\d+)/ && print $$1')

all: html pdf
new: clean all
pdf: ${ALLPDF}
html: ${ALLHTML}

%.pdf: %.md
	@echo $@
	@PANDOC_VERSION=$(PANDOC_VERSION) PERL5LIB=../lib \
		pandoc -s -S --filter ./$(subst -sample.md,.pl,$<) $< -o $@

%.html: %.md
	@echo $@
	@PANDOC_VERSION=$(PANDOC_VERSION) PERL5LIB=../lib \
		pandoc -s -S --filter ./$(subst -sample.md,.pl,$<) $< -o $@
	
clean:
	@rm -f *.pdf *.png *.html

