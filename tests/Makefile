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

RUNTEST=./runtest.sh

all:
	@for f in test???.xml; do \
	    $(RUNTEST) $$f; \
	    if [ $$? -eq 2 ]; then exit; fi; \
	done

listtests:
	@for f in test???.xml; do \
	    echo $$f; \
	    xsltproc --novalid description.xsl $$f \
	    	| awk -v mode=description -f description.awk \
		| sed 's/^/  /'; \
	done

clean:
	-@rm test???-flip.xml test???.log test???-expected.log test???.diff \
	     test???-uppaal.log

