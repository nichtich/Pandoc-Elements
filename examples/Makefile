ALLSAMPLES = $(basename $(wildcard *-sample.md))
ALLPDF = $(addsuffix .pdf,$(ALLSAMPLES))

all: ${ALLPDF}

%.pdf: %.md
	echo $(subst -sample.md,.pl,$<)
	PERL5LIB=../lib pandoc --filter ./$(subst -sample.md,.pl,$<) $< -o $@
	
clean:
	$(RM) -f ${ALLPDF} *.pyc 
	$(RM) -rf *-images
