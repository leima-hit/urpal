# $Id$
#
#  Copyright (c) 2008 Timothy Bourke (University of NSW and NICTA)
#  All rights reserved.
#
#  This program is free software; you can redistribute it and/or modify it
#  under the terms of the "BSD License" which is distributed with the
#  software in the file LICENSE.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the BSD
#  License for more details.
#
URPAL_VERSION=1.0.0
HEAP_SUFFIX=x86-linux
MLTONOPT=-loop-passes 1

SMLNJ=/opt/smlnj/bin

MLYACC=$(SMLNJ)/mlyacc
MLLEX=$(SMLNJ)/mllex
MLTON=mlton
HEAP2EXEC=$(SMLNJ)/heap2exec
STRIP=strip
CTAGS=exctags

SKIPCM=-type d -name '.cm' -prune -type f -o
SRC!=find . $(SKIPCM) -name '*sml' -o -name '*sig'
SRCDIRS=. ./cmdlang ./config ./graphviz ./graphviz ./lib \
	./maketest ./uppaal ./uppaalxml ./mcs51 ./layout

urpal: $(SRC) version.sml tags
	$(SMLNJ)/ml-build sources.cm Urpal.main urpal
	$(HEAP2EXEC) urpal.$(HEAP_SUFFIX) urpal
	@rm urpal.$(HEAP_SUFFIX)

withmlton: cmdlang/cmdlang.grm.sml cmdlang/cmdlang.lex.sml \
	   uppaal/uppaal.grm.sml uppaal/uppaal.lex.sml \
	   mcs51/mcs51.grm.sml mcs51/mcs51.lex.sml \
	   config/config.lex.sml version.sml
	$(MLTON) $(MLTONOPT) -mlb-path-map unix-path-map -verbose 1  urpal.mlb
	$(STRIP) urpal

mingw32: cmdlang/cmdlang.grm.sml cmdlang/cmdlang.lex.sml \
	 uppaal/uppaal.grm.sml uppaal/uppaal.lex.sml \
	 mcs51/mcs51.grm.sml mcs51/mcs51.lex.sml \
	 config/config.lex.sml version.sml
	$(MLTON) -target mingw32 -cc mingw32-gcc \
		 $(MLTONOPT) -mlb-path-map unix-path-map -verbose 1 \
		 urpal.mlb
	mv urpal urpal.exe
	mingw32-strip urpal.exe

winmlton: cmdlang/cmdlang.grm.sml cmdlang/cmdlang.lex.sml \
	  uppaal/uppaal.grm.sml uppaal/uppaal.lex.sml \
	  mcs51/mcs51.grm.sml mcs51/mcs51.lex.sml \
	  config/config.lex.sml version.sml
	$(MLTON) -mlb-path-map win-path-map -verbose 1 urpal.mlb

grmfiles: cmdlang/cmdlang.grm.sml uppaal/uppaal.grm.sml mcs51/mcs51.grm.sml
lexfiles: config/config.lex.sml uppaal/uppaal.lex.sml cmdlang/cmdlang.lex.sml \
    	  mcs51/mcs51.lex.sml

cmdlang/cmdlang.grm.sml: cmdlang/cmdlang.grm
	$(MLYACC) cmdlang/cmdlang.grm

cmdlang/cmdlang.lex.sml: cmdlang/cmdlang.lex
	$(MLLEX)  cmdlang/cmdlang.lex

config/config.lex.sml: config/config.lex
	$(MLLEX)  config/config.lex

uppaal/uppaal.grm.sml: uppaal/uppaal.grm
	$(MLYACC) uppaal/uppaal.grm

uppaal/uppaal.lex.sml: uppaal/uppaal.lex
	$(MLLEX)  uppaal/uppaal.lex

mcs51/mcs51.grm.sml: mcs51/mcs51.grm
	$(MLYACC) mcs51/mcs51.grm

mcs51/mcs51.lex.sml: mcs51/mcs51.lex
	$(MLLEX)  mcs51/mcs51.lex

version:
	@echo $(URPAL_VERSION)

version.sml:
	(echo "(* automatically generated - do not edit *)"; \
	 echo "structure Version = struct ";   \
	 echo "  val version=\"$(URPAL_VERSION)\";"; \
	 echo "  val svnversion=\"`svnversion`\";";  \
	 echo "end") > version.sml

tags: $(SRC)
	-$(CTAGS) -R --exclude=.cm --exclude=*.grm.sml *
	touch tags

clean:
	-@find . \( $(SKIPCM) -name *.grm.sml -o -name *.lex.sml \
		    -o -name *.grm.sig -o -name *.grm.desc \)    \
	 	-print -exec rm {} \;
	-@for f in $(SRCDIRS); do rm -r $$f/.cm 2>/dev/null; done

clobber: clean
	-@rm version.sml urpal urpal.exe 2>/dev/null
	-@rm tags 2>/dev/null

