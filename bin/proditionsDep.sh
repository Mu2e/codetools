#! /bin/bash 
#
# produce a dot file with Proditions dependence
#
#
# run with an Offline directory as the argument
#   if none, assume "./Offline"
#

OPATH="$1"
[ -z "$OPATH" ] && OPATH="Offline"
TEST=$(echo $OPATH | awk -F/ '{print $NF}' )
if [ "$TEST" != "Offline" ]; then
    echo "first argument must be a path which ends in Offline"
    exit 1
fi

if [ ! -d "$OPATH" ]; then
    echo "Offline directory \"$OPATH\" does not exist"
    exit 1
fi

if [ -z "$SETUP_CETBUILDTOOLS" ]; then
   VV=$( ups list -ak+ cetbuildtools | tail -1 | tr "\"" " " | awk '{print $2}' )
   setup cetbuildtools $VV
fi

OFN=proditions.dot
rm -f $OFN
echo "digraph {" >> $OFN
echo "  node [ shape=rectangle ]" >> $OFN

CFILES=$(ls -1 $OPATH/*Conditions/inc/*Cache.hh)
for FN in $CFILES
do
    NAME=$(echo $FN | tr "/." "  " | awk '{print $(NF-1)}' | sed 's/Cache//' )
    echo "\"$NAME\";" >> $OFN
    DEPS=$( grep ProditionsHandle $FN | grep -v make | grep -v include | tr "<>" "  " | awk '{print $3}')
    for DD in $DEPS
    do
	if [ $DD == "Tracker" ]; then
	    DDO="AlignedTracker"
	else
	    DDO=$DD
	fi
	echo "\"$NAME\" -> \"$DDO\";" >> $OFN
    done

done
echo "}" >> $OFN

[ -z "$SETUP_GRAPHVIZ" ] && setup graphviz
tred proditions.dot  | dot -Tpng -o proditions.png
