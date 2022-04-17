#! /bin/bash
#
# script to do secondary nightly validation tests
# This is laucnhed from the main script after the 
# main code build, since it uses that build as a base.  
# Once this is launched, it is independent of the min script.
#



echo_date() {
echo "[$(date)] $*" 
}

safe_cd() {
    local TDIR="$1"
    if [ -z "$TDIR" ]; then
	echo "ERROR - safe_cd no argument"
	exit 1
     fi
    local EDIR=$(readlink -f $TDIR)
    local OWD="$PWD"
    [ "$EDIR" == "$OWD" ] && return 0
    if [ ! -d $EDIR ]; then
	echo "ERROR - safe_cd not a valid dir: $EDIR"
	exit 1
    fi
    echo_date "safe_cd $EDIR"
    cd $EDIR
    if [ "$PWD" != "$EDIR" ]; then
	echo "ERROR - safe_cd did not suceed OWD=$OWD, EDIR=$EDIR, PWD=$PWD"
	exit 1
    fi
    return 0
}

basic_setups() {
    echo_date "start setups"
    source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
    source $HOME/bin/authentication.sh
}

repo_setups() {
    echo_date "start repo setups"

    rm -rf build link *.log .sconsign.dblite

    muse link $BUILD_DIR/Offline
    muse link $BUILD_DIR/Production
}


repo_build() {
    echo_date "start repo_build with $@"

    if [ "$PWD" != "$SBUILD_DIR/repo" ]; then
	echo "ERROR - repo_build was not in the secondary area!"
	return 1
    fi

    export REPO="$1"
    local RC=0
    rm -rf build

    git clone -q https://github.com/Mu2e/$REPO  || return 1
    (
        git -C $REPO show
	muse setup -1
	muse status
	muse build -j 20 --mu2eCompactPrint
    ) >& ${REPO}.log
    RC=$?
    echo_date "finish repo_build with $@, RC=$RC"

    RESULT="OK  "
    [ $RC -ne 0 ] && RESULT="FAIL"
    echo "REPORT   $RESULT $REPO build"

    rm -rf build $REPO

    return $RC
}

repo_test_Tutorial() {
    repo_build Tutorial
}

repo_test_TrkAna() {
    repo_build TrkAna
}

repo_test_TrackerAlignment() {
    repo_build TrackerAlignment
}

repo_test_REve() {
    repo_build REve
}


#
# $1 is job to do, ceSimReco or reco, or do both if blank
#
FPE_test() {

    local JOB="$1"

    echo_date "start FPE_test"

    if [ "$PWD" != "$SBUILD_DIR/repo" ]; then
	echo "ERROR - FPE_test was not in the secondary area!"
	return 1
    fi

    (
	muse setup -1
	muse status
	#muse build -j 20 --mu2eCompactPrint
	#RC=$?
	#[ $RC -ne 0 ] && exit 1

	cat > float.fcl << EOF
services.FloatingPointControl: {
    enableDivByZeroEx  : true
    enableInvalidEx    : true
    enableOverFlowEx   : false
    enableUnderFlowEx  : false   # See note below
    setPrecisionDouble : false   # see note below
    reportSettings     : true
}
EOF
	if [[ "$JOB" == "ceSimReco" || "$JOB" == ""  ]]; then
	    cat > ceSimReco_FPE.fcl << EOF
#include "Production/Validation/ceSimReco.fcl"
#include "float.fcl"
source.maxEvents: 1000
EOF
	    echo_date "start FPE ceSimReco"

	    mu2e -c ceSimReco_FPE.fcl
	    RC=$?
	    echo_date "end FPE ceSimReco RC=$RC"
	    [ $RC -ne 0 ] && exit 1
	fi

	if [[ "$JOB" == "reco" || "$JOB" == "" ]]; then
	    cat > reco_FPE.fcl << EOF
#include "Production/Validation/reco.fcl"
#include "float.fcl"
source.fileNames : ["$RECOTESTFN"]
source.maxEvents: 1000
EOF

	    echo_date "start FPE reco"
	    mu2e -c reco_FPE.fcl
	    RC=$?
	    echo_date "end FPE reco RC=$RC"
	    [ $RC -ne 0 ] && exit 1
	fi

	exit 0

    ) >& FPE.log

    RC=$?
    echo_date "finish FPE_test with RC=$RC"

    RESULT="OK  "
    [ $RC -ne 0 ] && RESULT="FAIL"
    echo "REPORT   $RESULT floating point error check $JOB"

    rm -rf build

    return $RC
}

#
# $1 is job to do, ceSimReco or reco, or do both if blank
#
sanitize() {

    local JOB="$1"

    echo_date "start sanitize"

    if [ "$PWD" != "$SBUILD_DIR/sanitize" ]; then
	echo "ERROR - sanitize was not in the secondary/sanitize area!"
	return 1
    fi

    rm -rf build Offline Production *.log *.fcl *.root *.art


    git clone -q https://github.com/Mu2e/Offline  || return 1
    git clone -q https://github.com/Mu2e/Production  || return 1

    (
        git -C Offline show
        git -C Production show
	muse setup -1
	muse status
	muse build -j 20 --mu2eCompactPrint --mu2eSanitize
	RC=$?
	[ $RC -ne 0 ] && exit 1

	# this turns off some checks which will stop the exe
	export ASAN_OPTIONS="verify_asan_link_order=0:alloc_dealloc_mismatch=0:detect_leaks=0"

	if [[ "$JOB" == "ceSimReco" || "$JOB" == ""  ]]; then
	    echo_date "start sanitize ceSimReco"
	    mu2e -n 500 -c Production/Validation/ceSimReco.fcl
	    RC=$?
	    echo_date "end sanitize ceSimReco RC=$RC"
	    [ $RC -ne 0 ] && exit 1
	fi


	if [[ "$JOB" == "reco" || "$JOB" == ""  ]]; then
	    echo_date "start sanitize reco"
	    mu2e -n 500 -c Production/Validation/reco.fcl -s $RECOTESTFN
	    RC=$?
	    echo_date "end sanitize reco RC=$RC"
	    [ $RC -ne 0 ] && exit 1
	fi

	NRE=$( grep -c "runtime error" sanitize.log )
	[ $NRE -gt 0 ] && exit 1

	exit 0

    ) >& sanitize.log
    RC=$?
    echo_date "finish sanitize with RC=$RC"
    echo_date "ls of sanitize area"
    ls -lh

    RESULT="OK  "
    [ $RC -ne 0 ] && RESULT="FAIL"
    echo "REPORT   $RESULT sanitize check $JOB"

    return $RC

}


send_report() {
    grep REPORT $LOGFN | sed 's/REPORT//' > $REPORT
    cat $REPORT | mail -r valJobSecondary \
	-s "valJobSecondary $(date +%m/%d/%y )" \
	rlc@fnal.gov,kutschke@fnal.gov,edmonds@fnal.gov,sophie@fnal.gov,rbonvent@fnal.gov,genser@fnal.gov
#	rlc@fnal.gov
}


echo_date "start valJobSecondary"


LOGFN=valJobSecondary.log
REPORT=valJobSecondary.txt
BUILD_DIR=/mu2e/app/users/mu2epro/nightly/current
SBUILD_DIR=/mu2e/app/users/mu2epro/nightly/secondary
# file which seems to be mysteriously stuck in dCache
#RECOTESTFN=/pnfs/mu2e/persistent/users/mu2epro/valjob/reco_031021/dig.brownd.CeEndpointMixTriggered.MDC2020k.001210_00000000.art
#RECOTESTFN=/pnfs/mu2e/persistent/users/mu2epro/valjob/reco_031021/dig.brownd.CeEndpointMixTriggered.MDC2020k.001210_00000001.art
# located here temporarily until these files can be read from dcache 10/29/21
RECOTESTFN=/mu2e/data/users/mu2epro/dig.brownd.CeEndpointMixTriggered.MDC2020k.001210_00000000.art

# the day of the week
WDAY=$(date +%a)

basic_setups

# run builds and tests on the app disk
mkdir -p $SBUILD_DIR/repo
safe_cd $SBUILD_DIR/repo  || exit 1
repo_setups
repo_test_Tutorial
repo_test_TrkAna
repo_test_TrackerAlignment
repo_test_REve

# art floating point error checking
if [ "$WDAY" == "Mon" ]; then
    FPE_test
fi

# run with sanitize (bounds check) switches
mkdir -p $SBUILD_DIR/sanitize
safe_cd $SBUILD_DIR/sanitize || exit 1
if [ "$WDAY" == "Tue" ]; then
    sanitize ceSimReco
fi

# temp: run this every day until the job completes normally
if [ "$WDAY" == "Wed" ]; then
    sanitize reco
fi


# return to source dir for the report
safe_cd $HOME/cron/val  || exit 1

send_report



