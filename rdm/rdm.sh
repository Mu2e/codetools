#! /bin/bash
#
# this is run by cron.  It sends mail and exits on error.
# $1 ia a keyword for which source to use
#
#

newFiles() {

    echo "[$(date)] Start newFiles $PROJECT"

    local TMP=$( mktemp )

    $RCOM uploadFiles > $TMP 2>&1
    local RC=$?
    cat $TMP
    [ $RC -ne 0 ] && return 10

    local FILES=$( cat $TMP | awk '{if($1=="NEWFILE") print $2}')
    [ -z "$FILES" ] && return 0

    for FN in $FILES
    do

	local TIER=$( echo $FN | awk -F. '{print $1}' )
	local OWNR=$( echo $FN | awk -F. '{print $2}' )
	if [[ "$TIER" != "raw" && "$TIER" != "etc" ]]; then
	    echo "[$(date)] Skipping non-raw, non-etc file $FN"
	    continue
	fi	
	if [ "$OWNR" != "mu2e" ]; then
	    echo "[$(date)] Skipping non-mu2e file $FN"
	    continue
	fi	

	local CRC=$( cat $TMP | awk '{if($2=="'$FN'") print $3}' )
	local FS=$FBASE/$PROJECT/upload/$FN
	if [ ! -f $FS ]; then
	    echo "[$(date)] scp $FN"
	    # could do retries, for now, continue and try on next cron
	    scp ${RNODE:+${RNODE}:}$RBASE/upload/$FN $FS
	    if [ $? -ne 0 ]; then
		echo "[$(date)] ERROR - scp failed for $FN"
		echo scp ${RNODE:+${RNODE}:}$RBASE/upload/$FN $FS
		[ -f $FS ] && mv $FS $FBASE/$PROJECT/error/${FN}.$(date +%s)
		return 1
	    fi
	fi

	# returns alder32:xxxxxx
	local CCRC=$(cat $(dirname $FS)/".(get)($(basename $FS))(checksum)")
	## strip leading zeros to match ecrc behavior
	#CCRC=$( echo $CCRC | sed 's/^0*//' )
	# tr removes embedded special chars
	CCRC=$( echo $CCRC | awk -F: '{print $2}' | tr -dc '[:alnum:]' )
	if [ "$CRC" != "$CCRC" ]; then
	    echo "[$(date)] ERROR - copy CRC failed: $CRC vs $CCRC for $FN"
	    [ -f $FS ] && mv $FS $FBASE/$PROJECT/error/${FN}.$(date +%s)
	    return 2
	fi
	echo $CRC > $FBASE/$PROJECT/upload/${FN}.crc

    done

    rm -f $TMP
}

jsonFiles() {

    echo "[$(date)] Start jsonFiles $PROJECT"

    local FILES=$( ls -1 $FBASE/$PROJECT/upload | \
	awk -F. '{print $1"."$2"."$3"."$4"."$5"."$6}' | sort | uniq )
    [ -z "$FILES" ] && return 0


    for FN in $FILES
    do

	local FS=$FBASE/$PROJECT/upload/${FN}
	local FSJ=$FBASE/$PROJECT/upload/${FN}.json
	local FSC=$FBASE/$PROJECT/upload/${FN}.crc
	if [ ! -f $FS ]; then
	    echo "ERROR - skipping $FN - data file missing"
	    continue
	fi
	if [ ! -f $FSC ]; then
	    echo "ERROR - skipping $FN - CRC file missing"
	    continue
	fi

	if [ ! -f $FSJ ]; then
	    printJson --no-parents $FS > $FSJ
	    echo "[$(date)] creating json file ${FN}.json"
	    if [ $? -ne 0 ]; then
		echo "ERROR - skipping $FN - could not make json"
		continue
	    fi
	fi

    done

    rm -f $TMP
}

ftsFiles() {

    echo "[$(date)] Start ftsFiles $PROJECT"

    local FILES=$( ls -1 $FBASE/$PROJECT/upload | \
	awk -F. '{print $1"."$2"."$3"."$4"."$5"."$6}' | sort | uniq )
    [ -z "$FILES" ] && return 0


    for FN in $FILES
    do
	local FS=$FBASE/$PROJECT/upload/${FN}
	local FSJ=$FBASE/$PROJECT/upload/${FN}.json
	local FSC=$FBASE/$PROJECT/upload/${FN}.crc
	local FSS=$FBASE/$PROJECT/stage/${FN}
	if [[ ! -f $FS || ! -f $FSJ || ! -f $FSC ]]; then
	    echo "ERROR - skipping $FN - some files missing"
	    ls -l $FBASE/$PROJECT/upload/${FN}*
	    continue
	fi

	local HASH=$( echo -n $FN | sha256sum | cut -c 1-5 )
	local SPREADER=$( printf "%03d" $((0x${HASH}%1000)) )

	local TIER=$( echo $FN | awk -F. '{print $1}' )
	if [ "$TIER" == "raw" ]; then
	    local OUTD=$FTSRAW/$SPREADER
	elif [ "$TIER" == "etc" ]; then
	    local OUTD=$FTSETC/$SPREADER
	else
	    echo "ERROR - tier not parsed, TIER=$TIER, FN=$FN"
	    continue
	fi

	echo "[$(date)] Moving $FN to $OUTD"
	if ! mv $FS $OUTD ; then
	    echo "ERROR - could not mv $FN to FTS $OUTD"
	    continue
	fi
	if ! mv $FSJ $OUTD ; then
	    echo "ERROR - could not mv $FNJ to FTS"
	    continue
	fi

	# mark the file staged
	if ! touch $FSS ; then
	    echo "[$(date)] ERROR - could not touch $FNS"
	    continue
	fi

	# rm CRC file
	if ! rm -f $FSC ; then
	    echo "[$(date)] ERROR - could not rm $FNC"
	fi
	
	# move the remote file position
	
	$RCOM mvStage $FN
	if [ $? -ne 0 ]; then
	    echo "[$(date)] ERROR - could not mvStage remote file $FN"
	    continue
	fi

    done

    rm -f $TMP
}


stageFiles() {

    echo "[$(date)] Start stageFiles $PROJECT"

    local FILES=$( ls -1 $FBASE/$PROJECT/stage )
    [ -z "$FILES" ] && return 0


    for FN in $FILES
    do
	local FSS=$FBASE/$PROJECT/stage/${FN}

	local EXISTS=$( samweb count-files "file_name=$FN" )
	[ $EXISTS -eq 0 ] && continue

	local LOC=$(samweb locate-file $FN)
	if [ $? -ne 0 ]; then
	    echo "[$(date)] ERROR - could not run sam-locate for $FN"
	    continue
	fi

	# if the location has a tape position stanza
	if [[ "$LOC" =~ "(" ]]; then

	    echo "[$(date)] $FN sam tape location found"
	    # move the remote file position
	
	    $RCOM mvDelete $FN
	    if [ $? -ne 0 ]; then
		echo "[$(date)] ERROR - could not mvDelete remote file $FN"
		continue
	    fi

	    echo "[$(date)] rm $FSS"
	    rm -f $FSS

	fi

	

    done

    rm -f $TMP
}


# run for each project
webProjectReport() {

    echo "[$(date)] Start webProjectReport $PROJECT"

    local WFN=$WEBDIR/project_${PROJECT}.txt
    echo "<BR><BR><h2> $PROJECT </h2><BR>" > $WFN
    echo "<PRE>" >> $WFN

    $RCOM findAllFiles  >> $WFN
    if [ $? -ne 0 ]; then
	echo "[$(date)] ERROR - could not run findAllFiles"
    fi

    local TMP=$( mktemp )
    $RCOM datasets  > $TMP
    if [ $? -ne 0 ]; then
	echo "[$(date)] ERROR - could not run findAllFiles"
    fi

    DSS=$( cat $TMP )
    local TMP1=$( mktemp )
    local TMP2=$( mktemp )
    for DS in $DSS
    do
	samweb list-files "dh.dataset=$DS" > $TMP
	while read FN
	do
	    LOC=$( samweb locate-file $FN )
	    if [[ "$LOC" =~ "(" ]]; then
		echo "     $FN" >> $TMP2
	    else
		echo "     $FN" >> $TMP1
	    fi
	done < $TMP
    done

    local N=$( cat $TMP1 | wc -l )
    printf " ************* %-10s %5d files\n" dCache $N >> $WFN
    cat $TMP1 >> $WFN

    local N=$( cat $TMP2 | wc -l )
    printf " ************* %-10s %5d files\n" tape $N >> $WFN
    cat $TMP2 >> $WFN
    echo "</PRE>" >> $WFN
    
}

runProject() {
    echo ""
    echo ""
    echo "[$(date)] Start running $PROJECT"

    newFiles || return $?
    jsonFiles || return $?
    ftsFiles || return $?
    stageFiles || return $?
    webProjectReport

    echo "[$(date)] Done running $PROJECT"
    return 0

}


setProject() {
    # for each project, define these vaules
    # remote node
    # remote node script
    # where the remote data directories are
    # whom to send email to 
    if [ "$PROJECT" = "trk" ]; then
	export RNODE=mu2edaq09
	export RSCRIPT=/home/mu2epro/bin/rdmRemote.sh
	export RCOM="ssh $RNODE $RSCRIPT"
	export RBASE=/data/rdm
	export EMAIL="rlc@fnal.gov"
    elif [ "$PROJECT" = "crv" ]; then
	export RNODE=""
	export RSCRIPT=/mu2e/app/home/mu2epro/RDM/crv/rdmRemote.sh
	export RCOM=$RSCRIPT
	export RBASE=/pnfs/mu2e/persistent/users/mu2epro/RDM/remote/crv
	export EMAIL="rlc@fnal.gov"
    else 
	echo "ERROR - unknown project configuration $PROJECT"
	return 1
    fi
    return 0
}

makeDirs() {
    if [ ! -d $FBASE/$PROJECT ]; then
	mkdir -p $FBASE/$PROJECT/log
	mkdir -p $FBASE/$PROJECT/upload
	mkdir -p $FBASE/$PROJECT/stage
	mkdir -p $FBASE/$PROJECT/error
	mkdir -p $BASE/log/$PROJECT
    fi
}

cleanLog() {
    (
	cd $BASE/log/$PROJECT
	local FNS=$( ls -1 | grep -v $DAY )

	for FN in $FNS
	do

	    local TT=$( echo $FN | cut -c 1-7 )
	    local OUT=$FBASE/$PROJECT/log/$TT
	    [ ! -d $OUT ] && mkdir -p $OUT

	    echo cleanlog $FN
	    cp $FN $OUT && rm $FN
	done
    )
    return 0
}


errorReport() {

    local TMP=$( mktemp )
    local SS=$(cat $BASE/log/$PROJECT/$DAY | \
	awk '{if(index($0,"Start running")>0) ss=NR}END{print ss}' )
    cat  $BASE/log/$PROJECT/$DAY | \
	awk -v ss=$SS '{if(NR>=ss)print $0}' > $TMP

    cat $TMP | mail -r rdm -s "RDM ERROR $PROJECT" $EMAIL

    rm -f $TMP

    return 0
}

dailyReport() {

#    TMP=$( mktemp )
#    SS=$ (cat $BASE/log/$PROJECT/$DAY | \
#	awk '{if(index($0,"Start project")>0) ss=NR}END{print ss}' )
#    cat  $BASE/log/$PROJECT/$DAY | \
#	awk -v ss=$SS '{if(NR>=ss)print $0}' > $TMP
#
#    cat $TMP | mail -r rdm -s "RDM ERROR $PROJECT" $EMAIL
#
#    rm -f $TMP

    return 0
}


# run for each cron, aggregates projects
webReport() {
    local PFILES=$( ls $WEBDIR | grep project | grep txt )
    rm $WEBDIR/rdm.html

    echo "<HEAD><TITLE>RDM</TITLE></HEAD>" >> $WEBDIR/rdm.html
    echo "<BODY>" >> $WEBDIR/rdm.html
    echo "<meta http-equiv=\"refresh\" content=\"1000\">" >> $WEBDIR/rdm.html

    for P in $PFILES
    do
	cat $WEBDIR/$P >> $WEBDIR/rdm.html
    done

    echo "<BR><BR>Last updated $(date)<BR>" >> $WEBDIR/rdm.html
    echo "</BODY>" >> $WEBDIR/rdm.html
    
}



#
# main
#

if [ "$(hostname -s)" != "mu2egpvm01" ]; then
    echo "ERROR - rdm.sh must run on mu2egpvm01 in order to access the web area"
    exit 1
fi


BASE=/mu2e/app/home/mu2epro/RDM
LOCK=$BASE/rdmLock

[ -f $LOCK ] && exit 0
echo "$(date)  $$" > $LOCK

FBASE=/pnfs/mu2e/persistent/users/mu2epro/RDM
FTSRAW=/pnfs/mu2e/persistent/fts/phy-raw
FTSETC=/pnfs/mu2e/persistent/fts/phy-etc
WEBDIR=/web/sites/mu2e.fnal.gov/htdocs/atwork/computing/ops/rdm
PROJECTS="$@"
shift $#

echo "[$(date)] rdm starting"

cd $BASE

source /mu2e/app/home/mu2epro/bin/authentication.sh

RC=0
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
RC=$(( $RC + $? ))
#  # pgit backing builds - will need to change over to Muse when ready
#  SFILE=$( ls -1tr /cvmfs/mu2e-development.opensciencegrid.org/branches/master/*/SLF7/prof/Offline/setup.sh | tail -1 )
#  source $SFILE
setup muse
muse setup Offline
RC=$(( $RC + $? ))
setup mu2etools
RC=$(( $RC + $? ))
setup encp  v3_11c -q stken
RC=$(( $RC + $? ))
setup sam_web_client
RC=$(( $RC + $? ))

if [ $RC -ne 0 ]; then
    rm $LOCK
    exit 1
fi

for PROJECT in $PROJECTS
do

    echo "[$(date)] rdm starting $PROJECT"

    setProject || continue

    makeDirs
  
    MON=$(date +"%Y_%m" )
    DAY=$(date +"%Y_%m_%d" )

    runProject >> $BASE/log/$PROJECT/$DAY 2>&1
    RC=$?

    [ $RC -ne 0 ] && errorReport

    cleanLog
    webReport

    echo "[$(date)] rdm done $PROJECT"

done

rm $LOCK
exit 0


# "output" - where you write output
# "upload" - you mv the files to here when ready to upload
# "delete" - mu2epro will mv the files from upload to delete
# when the copy is safe on tape.  You can delete on your schedule.
# "temp" - you can make a copy of the file to here from output if you want
