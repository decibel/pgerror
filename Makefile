include pgxntool/base.mk

# TODO: Remove this hack after pgxntool is fixed
VERSION 	 = $(shell $(PG_CONFIG) --version | awk '{sub("(alpha|beta|devel).*", "", $$2); print $$2}')

GE95		 := $(call test, $(MAJORVER), -ge, 95)

.PHONY: sql/pgerror.sql
sql/pgerror.sql: sql/pgerror.in.sql
ifeq ($(call test, $(MAJORVER), -ge, 95),yes)
	@sed -e 's/-- GE95//' $< > $@
else
	@cp $< $@
endif

