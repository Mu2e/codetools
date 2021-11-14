#! /bin/bash
#
# $1 = the setup dir without Offline
# $2 = the command: ceSimReco or potSim
# ceSimReco 1500
# potSim 150

DD=$1
CC=$2
shift
shift

source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
source $DD/Offline/setup.sh

ARTFN=${$}.art
NTPFN=${$}.root
FCLFN=$(mktemp)

if [ "$CC" == "ceSimReco" ]; then
    cp $MU2E_BASE_RELEASE/Validation/fcl/ceSimReco.fcl $FCLFN
    NEV=2000
else
    cp $MU2E_BASE_RELEASE/Validation/fcl/potSim.fcl $FCLFN
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

