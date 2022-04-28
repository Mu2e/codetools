#!/bin/bash
#
# a cron job to safely run moveCIBranch.sh
# need to prevent multiple cvmfs accesses
#
#
cd /mu2e/app/home/mu2epro/cron/git
if [ -f lock ]; then
   DT=$(( $(date +%s) - $(stat --printf="%Y" lock) ))
   if [ $DT -lt 3000 ]; then
       echo "[$(date)] exit on lock, DT=$DT"
       exit 0
   else
       echo "[$(date)] force remove lock DT=$DT"
       rm -f lock
       echo " removed git branch lock, dt=$DT" | \
           mail -r gitCI -s "git cron removed lock" rlc@fnal.gov
   fi
fi

touch lock

echo "[$(date)] moving Muse CI build"

./moveCIBranch.sh >& moveCIBranch.log

rm lock

exit 0
