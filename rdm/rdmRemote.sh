#! /bin/bash
#
# script that is run remotely by mu2epro ~/RDM.sh,
# driven by a cron job on mu2esamgpvm01
# the data source directory may be different for each teststand, 
# and is set below
#
#

findAllFiles() {
    for SD in temp output upload stage delete
    do
       local N=$( find $DD/$SD -type f | wc -l )
       printf " ************* %-10s %5d files\n" $SD $N
       find $DD/$SD -type f -ls | awk '{printf "%9s %s %s %s %s\n",$7,$8,$9,$10,$11 }'
    done
}

datasets() {
    find $DD -type f -ls | awk '{print $NF }' | \
	awk -F/ '{print $NF}' | \
	awk -F. '{print $1"."$2"."$3"."$4"."$6}' | sort | uniq
}

findOutputFiles() {
    find $DD/output -type f -ls
}

uploadFiles() {
    source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh || return 1
    setup encp v3_11c -q stken || return 2

    FILES=$( ls $DD/upload )

    if [ -z "$FILES" ]; then
	echo "[$(date)] No new files in remote upload"
	return 0
    fi

    for FN in $FILES
    do
	FS=$DD/upload/$FN
	#echo newFiles operating on $FN
	LINE=$( ecrc -1 -h $FS ) || return 3
	CRC=$( echo $LINE | awk '{print $2}' )
	# make sure it is 8 char, like dcache uses, and strip 0x prefix
	CRC=$( printf "%08x" $CRC )
	echo "NEWFILE $FN $CRC"
    done

    return 0
}

mvStage() {
    FN="$1"
    if [ ! -f "$DD/upload/$FN" ]; then
	echo "ERROR - mvStage could not find or mv file $FN"
	return 10
    fi
    mv $DD/upload/$FN $DD/stage/$FN || return 11
}

mvDelete() {
    FN="$1"
    if [ ! -f "$DD/stage/$FN" ]; then
	echo "ERROR - mvDelete could not find or mv file $FN"
	return 10
    fi
    mv $DD/stage/$FN $DD/delete/$FN || return 21
}

#
# main
#

# where the data mover subdirs are
# this may be different in each test stand
if [ -n "$RDM_DD" ]; then
    DD="$RDM_DD"
else
    DD=/data/rdm
fi

command="$1"
shift


if [ "$command" == "findAllFiles" ]; then
    findAllFiles
elif [ "$command" == "findOutputFiles" ]; then
    findOutputFiles
elif [ "$command" == "uploadFiles" ]; then
    uploadFiles
elif [ "$command" == "mvStage" ]; then
    mvStage "$@"
elif [ "$command" == "mvDelete" ]; then
    mvDelete "$@"
elif [ "$command" == "datasets" ]; then
    datasets "$@"
else
    echo "ERROR - unknown command $command"
    exit 1
fi

exit $?
