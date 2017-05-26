.PHONY: setup
setup: setup-master setup-ghpages setup-ghissues

LIBDIR ?= lib
include $(LIBDIR)/main.mk

# Check that everything is ready
ifeq (,$(wildcard .git))
$(error Please make sure that this is a git repository by running "git init")
endif
GIT_ORIG := $(shell git branch 2>/dev/null | grep '*' | cut -c 3-)
ifneq (1,$(words $(GIT_ORIG)))
$(error If you are just starting out, please commit something before starting)
endif
ifneq (master,$(GIT_ORIG))
$(warning Using a branch called 'master' is recommended)
endif

LATEST_WARNING := $(strip $(foreach draft,$(join $(drafts),$(draft_types)),\
	   $(shell grep -q $(basename $(draft))-latest $(draft) || \
		echo $(draft) should include a name of $(basename $(draft))-latest. )))
ifneq (,$(LATEST_WARNING))
$(warning Check names: $(LATEST_WARNING))
endif
ifneq (,$(strip $(shell git status -s --porcelain 2>/dev/null | egrep -v '^.. (.targets.mk|$(LIBDIR)/?|$(LIBDIR)/.template-files.mk)$$')))
$(error You have uncommitted changes, please commit them before running setup)
endif
ifneq ($(GIT_REMOTE),$(shell git remote 2>/dev/null | grep '^$(GIT_REMOTE)$$'))
$(error Please configure a remote called '$(GIT_REMOTE)' before running setup)
endif
ifeq (,$(shell git show-ref origin/$(GIT_ORIG)))
$(error Please push the '$(GIT_ORIG)' branch to '$(GIT_REMOTE)', e.g., "git push $(GIT_REMOTE) $(GIT_ORIG)")
endif

TEMPLATE_FILES := \
  Makefile .gitignore \
  CONTRIBUTING.md LICENSE.md \
  .travis.yml circle.yml

TEMPLATE_FILE_MK := $(LIBDIR)/.template-files.mk
include $(TEMPLATE_FILE_MK)
$(TEMPLATE_FILE_MK): $(LIBDIR)/setup.mk
	@echo '# Automatically generated setup rules' >$@
	@$(foreach f,$(TEMPLATE_FILES),\
	  echo $(f): $(LIBDIR)/template/$(f) >>$@;\
	  echo '	-cp $$< $$@' >>$@;)

.PHONY: setup-files
setup-files: $(TEMPLATE_FILES)
	git add $(join $(drafts),$(draft_types))
	git add $^

ifeq (true,$(USE_XSLT))
setup-master: setup-makefile setup-circle
.PHONY: setup-makefile
setup-makefile: Makefile
	sed -i~ -e '1{h;s/^.*$$/USE_XSLT := true/;p;x}' $<
	@-rm -f $<~
	git add $<

.PHONY: setup-circle
setup-circle: circle.yml
	sed -i~ -e '/^dependencies:/,/^  pre:$$/{p;s/^  pre:$$/    - sudo apt-get -qq update; sudo apt-get -q install xsltproc/;t;d}' $<
	@-rm -f $<~
	git add $<
endif # USE_XSLT

.PHONY: setup-gitignore
setup-gitignore: .gitignore
ifndef SUBMODULE
	echo $(LIBDIR) >>$<
endif
	$(foreach x,$(filter-out .xml,$(join $(drafts),$(draft_types))),\
	  echo $(basename $(x)).xml >>$<;)
	git add $<

README.md: $(LIBDIR)/init-readme.sh $(drafts_xml) $(filter %.md, $(TEMPLATE_FILES))
	$(LIBDIR)/init-readme.sh $(GITHUB_USER) $(GITHUB_REPO) $(filter %.xml,$^) >$@
	git add $@ $(filter %.md, $(TEMPLATE_FILES))

.PHONY: setup-master
setup-master: setup-files README.md setup-gitignore
	git $(CI_AUTHOR) commit -m "Setup repository for $(firstword $(drafts)) using https://github.com/martinthomson/i-d-template"
	-ln -s ../../lib/pre-commit.sh .git/hooks/pre-commit

.PHONY: setup-ghpages
setup-ghpages:
	$(LIBDIR)/init-branch.sh gh-pages index.html

.PHONY: setup-ghissues
setup-ghissues:
	$(LIBDIR)/init-branch.sh gh-issues issues.json pulls.json
