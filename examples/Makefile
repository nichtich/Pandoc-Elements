ALLSAMPLES = $(basename $(wildcard *-sample.md))
ALLPDF = $(addsuffix .pdf,$(ALLSAMPLES))

PANDOC_VERSION=$(shell pandoc --version | perl -E '<> =~ /pandoc (\d+\.\d+)/ && print $$1')

all: ${ALLPDF}

%.pdf: %.md
	@echo $(subst -sample.md,.pl,$<)
	@PANDOC_VERSION=$(PANDOC_VERSION) PERL5LIB=../lib \
		pandoc --filter ./$(subst -sample.md,.pl,$<) $< -o $@
	
clean:
	@$(RM) -f ${ALLPDF} *.pyc 
	@$(RM) -rf *-images
