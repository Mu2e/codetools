#!/bin/bash
#
# THis script is triggers by the jenkins process which pools for
# changes in the head of the Offline git repo.  When triggered,
# Offline is built andm in a separate process, it is pulled to
# /cvmfs/mu2e-development
#
#
# expects in the environment:
# label=7
# GIT_BRANCH=origin/master (or other branch)
#

initialize() {
  echo "[$(date)] GIT_BRANCH=$GIT_BRANCH"
  echo "[$(date)] printenv"
  printenv
  echo "[$(date)] df -h"
  df -h
  echo "[$(date)] quota"
  quota -v
  echo "[$(date)] PWD"
  pwd
  echo "[$(date)] ls of local dir"
  ls -al
  echo "[$(date)] cpuinfo"
  head -30  /proc/cpuinfo

  local ARCH=$( grep -m 1 vendor_id /proc/cpuinfo | awk '{print $NF}' )
  local NPROC=$( grep -m 1 processor /proc/cpuinfo | awk '{print $NF}' )
  echo "[$(date)] architecture $ARCH"
  echo "[$(date)] number of processors $NPROC"

  mkdir -p copyBack

  return 0
}

#
# checkout the main repo, branch $BRANCH
# set HASH for this commit
#
getCode() {

    echo "[$(date)] clone"
  # pull the main repo
    git clone https://github.com/Mu2e/Offline  || return 1

    # let git avoid doing an explicit cd here
    GD=" -C Offline "

    git $GD remote rename origin mu2e  || return 2

    git $GD checkout "$BRANCH" || return 3

    export HASH=$( git $GD rev-parse HEAD | cut -c 1-8 )
    [ $? -ne 0 ] && return 4

    git clone https://github.com/Mu2e/Production  || return 1


    return 0

}


checkExists() {

    # see if this hash is already built
    # eventually may need to check this platform specifically
    # when there are multiple platforms
    local TDIR=$BASECDIR/$BRANCH/$HASH/Offline
    if [ -d "$TDIR" ]; then
        echo "[$(date)][$BRANCH] is up to date at build $BUILD"
        return 1
    fi

    return 0

}

#
# buildBranch with BRANCH=branchName
# cleanup Offline, checkout this branch, see if this hash
# has already has been put on cvmfs, if not, build it and make a tarball
# defining this function with "()" causes it to run in a subshell
# to allow multiple setups in one job
#
buildBranch() {

    echo "[$(date)] start build for hash $HASH with BUILD=$BUILD"

    # setup currently redefines BUILD, so save it
    MBUILD=$BUILD
    muse setup -q "$BUILD"
    BUILD=$MBUILD
    RC=$?
    if [ $RC -ne 0 ]; then
        echo "[$(date)] failed to run muse setup"
        return 1
    fi

    muse status

    #local SHORT=$MUSE_BUILD_BASE/Offline/lib/libmu2e_Validation_root.so
    #muse build -j 20 --mu2eCompactPrint  $SHORT >& build.log
    muse build -j 20 --mu2eCompactPrint --mu2ePyWrap >& build.log
    RC=$?
    if [ $RC -ne 0 ]; then
        echo "[$(date)] failed to run muse build"
        cat build.log
        return 8
    fi

    echo "[$(date)] start deps"
    muse build DEPS
    echo "[$(date)] start gdml"
    muse build GDML
    echo "[$(date)] start git packing"
    muse build GITPACK
    echo "[$(date)] start rm of build temp areas"
    muse build RMSO

    # save the log file
    cp build.log $MUSE_BUILD_BASE/Offline/gen/txt/build.txt
    ls -al $MUSE_BUILD_BASE/Offline/gen/txt
    cp build.log copyBack/build_${BUILD}.log

    return 0
}

tarball() {

    echo "[$(date)] start tarball"

    local FDIR="$BRANCH/$HASH"
    local TBALL=copyBack/${BRANCH}+${HASH}+${LABEL}.bz2

    muse setup

    mkdir tar

    echo "[$(date)] muse tarball"
    muse tarball -e ./tar -t ./tar -r $FDIR >& tar.log
    [ $? -ne 0 ] && exit 1

    TBALL2=$( find tar -type f | head -1)
    echo "made tarball $TBALL2"
    ls -l $TBALL2

    mv $TBALL2 $TBALL
    [ $? -ne 0 ] && exit 1

    return 0

}

# set a modern git, initial paths
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh

export BUILDTOP=$PWD
export BASECDIR=/cvmfs/mu2e-development.opensciencegrid.org/museCIBuild
export LABEL=$label

# print info, check dirs
initialize

# this script is run for one branch
export BRANCH=$( echo $GIT_BRANCH | awk -F/ '{print $NF}' )

# clone and checkout BRANCH, set HASH
getCode
RC=$?
[ $RC -ne 0 ] && exit $RC

# check if this is already built
# I'm not sure why, but I did this in previous CI
checkExists
RC=$?
[ $RC -ne 0 ] && exit $RC

for BUILD in prof debug
do
    # in parens so runs in subshell and setup does not persist
    ( buildBranch )
    RC=$?
    [ $RC -ne 0 ] && exit $RC
done

( tarball )
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[$(date)] ls copyBack area"
ls -l copyBack

exit 0
