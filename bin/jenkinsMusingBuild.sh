#!/bin/bash
#
# build musings based on files in MuseConfig/musing
# inputs from jenkins parameters:
# MUSING=SimJob
# VERISON=v00_00_00
# label=prof
#


echo "[`date`] printenv"
printenv
echo "[`date`] df -h"
df -h
echo "[`date`] quota"
quota -v
echo "[`date`] PWD"
pwd
export LOCAL_DIR=$PWD
echo "[`date`] ls of local dir"
ls -al
echo "[`date`] cpuinfo"
cat /proc/cpuinfo | head -30
NCPU=$(cat /proc/cpuinfo | grep -c processor)

echo "[`date`] initial setup"
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
[ $? -ne 0 ] && exit 1
setup muse
[ $? -ne 0 ] && exit 1

echo "[`date`] printenv after setup"
printenv


echo "[$(date)] starting with MUSING=$MUSING VERSION=$VERSION label=$label"

if [ -z "$MUSING" ]; then
    echo "ERROR - required MUSING parameter is not set"
    exit 1
fi
if [ -z "$VERSION" ]; then
    echo "ERROR - required VERSION parameter is not set"
    exit 1
fi
if [ -z "$label" ]; then
    echo "ERROR - required label parameter is not set"
    exit 1
fi

for DD in $(ls -1 | grep -v codetools)
do
    rm -rf $DD
done

mkdir copyBack

echo "[$(date)] clone MuseConfig"
git clone -q https://github.com/Mu2e/MuseConfig
[ $? -ne 0 ] && exit 1

if [ ! -f MuseConfig/musing/$MUSING ]; then
    echo "ERROR - file MuseConfig/musing/$MUSING not found"
    exit 1
fi

NMATCHES=$( cat MuseConfig/musing/$MUSING | sed 's/#.*$//' |
    awk -v t=$VERSION '{if($1==t) { print $0 } }' | wc -l )

if [ $NMATCHES -eq 0 ]; then
    echo "ERROR - file MuseConfig/musing/$MUSING does not contain version $VERSION"
    exit 1
fi

if [ $NMATCHES -gt 1 ]; then
    echo "ERROR - file MuseConfig/musing/$MUSING has more than one line for $VERSION"
    exit 1
fi

DEPS=$( cat MuseConfig/musing/$MUSING | sed 's/#.*$//' |
    awk -v t=$VERSION '{if($1==t) { for(i=2;i<=NR; i++) print $i " "} }' )


echo "[$(date)] found dependecies $DEPS"

# first find the envset, if there is one

REPOS=""
ENVSET=""
# regex for version strings like p011 or u000
ree="^[pu][0-9]{3}$"
for DD in $DEPS
do
    WW=$(echo $DD | awk -F/ '{print $1}' )
    if [ "$WW" == "envset"]; then
        WW=$(echo $DD | awk -F/ '{print $2}' )
        if [[ ! "$WW" =~ $ree ]]; then
            echo "ERROR - malformed envset $DD"
            exit 1
        fi
        ENVSET=$WW
        echo "[$(date)] found envset $ENVSET"
    else
        REPOS="$REPOS $DD"
    fi
done

# now checkout or link repos

if [ -z "$REPOS" ]; then
    echo "ERROR - no actual dependencies found in deps: $DEPS"
    exit 1
fi

MUSINGS=/cvmfs/mu2e.opensciencegrid.org/Musings

linkReg="^link/*"
for REPO in $REPOS
do
    if [[ $REPO =~ $linkReg ]]; then
        RR=$(echo $REPO | awk -F/ '{print $2}' )
        VV=$(echo $REPO | awk -F/ '{print $3}' )
        echo "[$(date)] linking $RR/$VV"
        muse link $MUSINGS/$RR/$VV/$RR
        [ $? -ne 0 ] && exit 1
    else
        RR=$(echo $REPO | awk -F/ '{print $1}' )
        VV=$(echo $REPO | awk -F/ '{print $2}' )
        echo "[$(date)] cloning $RR/$VV"
        git clone -q https://github.com/Mu2e/$RR
        [ $? -ne 0 ] && exit 1
        git -C $RR checkout $VV
        [ $? -ne 0 ] && exit 1
    fi

done

echo "[$(date)] muse setup -q $label $ENVSET"
muse setup -q $label $ENVSET
[ $? -ne 0 ] && exit 1

echo "[$(date)] muse build"
muse build -j $NCPU --mu2eCompactPrint
[ $? -ne 0 ] && exit 1

[]

#git -C Offline checkout -b temp_work $MU2E_TAG
#[ $? -ne 0 ] && exit 1
#
#echo "[`date`] show what is checked out"
#git -C Offline show -1
#git -c Offline status
#
#echo "[$(date)] muse setup"
#muse -v setup -1 -q $BUILDTYPE
#[ $? -ne 0 ] && exit 1
#
#LOG=copyBack/build-${MU2E_TAG}-${MUSE_STUB}.log
#
#echo "[$(date)] muse build"
#muse build -j 20 >& $LOG
#if [ $? -eq 0 ]; then
#  echo "[$(date)] build success"
#else
#  echo "[$(date)] build failed - tail of log:"
#  tail -100 $LOG
#  exit 1
#fi
#
#RLOG=copyBack/build-release-${MU2E_TAG}-${MUSE_STUB}.log
#
#echo "[$(date)] muse build RELEASE"
#muse build RELEASE >& $RLOG
#[ $? -ne 0 ] && exit 1
#
#cp $LOG $MUSE_BUILD_BASE/Offline/gen/txt
#cp $RLOG $MUSE_BUILD_BASE/Offline/gen/txt
#
#mkdir tar
#
#echo "[$(date)] muse tarball"
#muse tarball -e copyBack -t ./tar -r Offline/$MU2E_TAG
#[ $? -ne 0 ] && exit 1

exit 0
