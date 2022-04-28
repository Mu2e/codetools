#!/bin/bash
#
# check for a new CI build on jenkins.  If a ne one is there,
# copy the tarball to staging area and trigger a script on cvmfs server to
# pull the tarball to /cvmfs/mu2e-development
#

cd /mu2e/app/home/mu2epro/cron/git

source /mu2e/app/home/mu2epro/bin/authentication.sh

#ps  -o pid -C mu2eCIBranch.sh h

#echo long
#ps -fwww f
#echo short
#ps  -C mu2eCIBranch.sh h


#/usr/krb5/bin/klist
TDIR=/mu2e/data/users/mu2epro/git/muse


PART1="https://buildmaster.fnal.gov/buildmaster/view/mu2e/job/mu2e_muse_ci_build/"
PART2="/lastSuccessfulBuild/artifact/copyBack/"


echo "[$(date)] Starting"

FAIL=false
ACTION=0

for FLAVOR in SLF7
do
    URL=${PART1}label=${FLAVOR}$PART2
    echo "[$(date)] read and parse " $URL
    # Jenkins 2.0 requires ~/.elinks/elinks.conf to turn off ssl check
    elinks --dump "$URL" | grep bz2 | grep http | head -1 | awk '{print $2}' > url.txt
    echo "[$(date)] url"
    cat url.txt
    FN=$(cat url.txt | awk -F/ '{print $NF}' )
    echo "[$(date)] file $FN"
    if [ -z "$FN" ]; then
        echo "[$(date)] did not find tarball, skipping"
        FAIL=true
        continue
    fi

    if ls $TDIR/$FN >& /dev/null ; then
        echo "[$(date)] tarball exists, skipping"
        continue
    fi

    ACTION=1
    echo "[$(date)] wget $FN"
    #echo wget -O $TDIR/$FN -o transfer_${FN}.log $URL/$FN
    wget --no-check-certificate \
        -q -O $TDIR/$FN -o transfer_${FN}.log $URL/$FN
    RC=$?
    if [ $RC -ne 0 ]; then
        echo "[$(date)] wget failed, skipping"
        FAIL=true
        continue
    fi

    echo "[$(date)] cvmfs push $FN"
    ssh -K -l cvmfsmu2edev oasiscfs.fnal.gov "/home/cvmfsmu2edev/pullCIBranch.sh $FN"
    RC=$?
    if [ $RC -ne 0 ]; then
        echo "[$(date)] cvmfsmu2edev ssh command failed"
        FAIL=true
        continue
    fi
done


# clean up older tarballs

BRANCHES=$( ls -1 $TDIR | awk -F+ '{print $1}' | sort | uniq )

TMP=$( mktemp )
for BRANCH in $BRANCHES
do
    ls -tr $TDIR/${BRANCH}+* > $TMP
    N=$( cat $TMP | wc -l )
    if [ $N -gt 5 ]; then
        NDEL=$(( $N - 10 ))
        FILES=$( cat $TMP | head -$NDEL )
        for FILE in $FILES
        do
            echo "[$(date)] purging $FILE"
            rm -f $FILE
        done
    fi

done

if [ $ACTION -ne 0 ]; then
  cat moveCIBranch.log | mail -r moveCIBranch \
    -s " moveCIBranch log " rlc@fnal.gov
fi

rm -f $TMP

if [ "$FAIL" == "true" ]; then
#pwd
#ls -l
    cp museCIBuild.log museCIBuild_fail_$(date +%s).log
  exit 1
fi

# remove older log files
find . -name "*.log" -ctime +30 -delete

exit 0
