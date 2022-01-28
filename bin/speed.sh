#! /bin/bash
#
# this runs speed test jobs every half hour for 10 hours
# to compare two builds, start this script, once for each build,
# at the same time (within a few minutes).  It will write to the defualt dir
# save the output of this script to a log file, and parse the logged times
#
# $1 = the Muse build dir (the dir that contains Offline and Production)
# $2 = the command: ceSimReco or potSim
#

DD=$1
CC=$2
shift
shift

source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
muse setup $DD

ARTFN=${$}.art
NTPFN=${$}.root
FCLFN=$(mktemp)

if [ "$CC" == "ceSimReco" ]; then
    cp $MUSE_WORK_DIR/Production/Validation/ceSimReco.fcl $FCLFN
    NEV=2000
else
    cp $MUSE_WORK_DIR/Production/Validation/potSim.fcl $FCLFN
    NEV=300
fi

N=0
while [ $N -lt 20 ]; 
do
    MM=$(date +%M)  
    while [[ "$MM" != "01" && "$MM" != "31"  ]]; 
    do
	sleep 30
	MM=$(date +%M) 
    done

    echo [$(date)] starting $N
    
    # alter the seed each time in case there is systematic
    # difference in how old and new run on a particular seed
    echo "services.SeedService.baseSeed: 5915422"${N} >> $FCLFN
    mu2e -n $NEV -c $FCLFN -T $NTPFN -o $ARTFN

    rm -f $NTPFN $ARTFN
    
    N=$(($N+1))
done

rm -f $FCLFN

