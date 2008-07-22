#!/bin/sh
#
# $Id$

#set -v

XSLTPROC="xsltproc --novalid "
GETDESC="$XSLTPROC description.xsl"

AWK=awk
URPAL=./urpal
VERIFYTA=verifyta
ME=`basename $0`
DEBUG=0
RMTMP=1
VERIFY=1

# ##

trap "echo 'Terminated Early'; exit 2" 2

while getopts vhkn o
do case "$o" in
	h)	echo "usage: $ME [-hvkn] <testsrc.xml>"
		echo "       -h   show this help message"
		echo "       -v   show more output"
		echo "	     -k   keep temporary files"
		echo "       -n   skip verification with Uppaal"
		exit 0
		;;
	v)	DEBUG=1   ;;
	k)	RMTMP=0   ;;
	n)	VERIFY=0  ;;
    esac
done
shift $(($OPTIND-1))
TESTSRC="$1"

if [ -z "$TESTSRC" -o ! -f "$TESTSRC" ]; then
    echo "$ME: no filename (-h for help)" 1>&2
    exit 1
fi

# ##

LAYOUT_OPTION=`$GETDESC $TESTSRC | $AWK -v mode=setlayout -f description.awk`
EVAL_OPTION=`$GETDESC $TESTSRC | $AWK -v mode=eval -f description.awk`
TESTPRE=`expr "$TESTSRC" : '\(.*\)\.xml'`

TESTOUT="$TESTPRE.log"
UPPOUT="$TESTPRE-uppaal.log"
DIFFOUT="$TESTPRE.diff"
TESTOUT_EXPECTED="$TESTPRE-expected.log"
ERROR_EXPECTED=`$GETDESC $TESTSRC | $AWK -v mode=error -f description.awk`
SYSTEM=`$GETDESC $TESTSRC | $AWK -v mode=system -f description.awk`

$GETDESC $TESTSRC | $AWK -v mode=stderr -f description.awk > $TESTOUT_EXPECTED

echo +---------------------------------------------------------------------
echo "| $TESTSRC"
$GETDESC $TESTSRC | $AWK -v mode=description -f description.awk | sed 's/^/| /'

CMD="$URPAL "$LAYOUT_OPTION" "$EVAL_OPTION" --input=$TESTSRC --output=$TESTPRE-iflip.xml"
if [ $DEBUG -eq 1 ]; then echo $CMD; fi
$CMD >$TESTPRE-flip.xml 2>$TESTOUT
ERROR=$?
$XSLTPROC --stringparam system "$SYSTEM" \
    --output $TESTPRE-flip.xml change_system.xsl $TESTPRE-iflip.xml
rm $TESTPRE-iflip.xml

diff -b $TESTOUT_EXPECTED $TESTOUT > $DIFFOUT
DIFFRESULT=$?

if [ $ERROR -ne $ERROR_EXPECTED ]; then
    echo "| FAILED (expected $ERROR_EXPECTED, got $ERROR)"
elif [ $DIFFRESULT -ne 0 ]; then
    echo "| FAILED (difference on stderr expected< >actual)"
    cat $DIFFOUT | grep '^[><-]'
else
    if [ $VERIFY -eq 1 ]; then
	VER_EXPECTED=`$GETDESC $TESTSRC | $AWK -v mode=uppaalerror -f description.awk`
	$VERIFYTA -s -q -f $TESTPRE $TESTPRE-flip.xml test.q 2>&1 > $UPPOUT
	VER_RESULT=$?

	if grep -q 'Property is satisfied.' $UPPOUT; then
	    if [ $VER_RESULT -eq $VER_EXPECTED ]; then
		if [ $VER_EXPECTED -ne 0 ]; then
		    echo "| PASSED (verification failure expected)"
		else
		    echo "| PASSED"
		fi
		if [ $RMTMP -eq 1 ]; then rm $UPPOUT; fi
	    else
		echo "| FAILED (verification in Uppaal)"
	    fi
	else
	    echo "| FAILED (Err is reachable)"
	fi
    else
	echo "| PASSED"
    fi

    if [ `stat -f %z $TESTOUT` -eq 0 ]; then rm $TESTOUT; fi
fi

if [ $RMTMP -eq 1 ]; then rm $TESTOUT_EXPECTED $DIFFOUT; fi

