#! /bin/bash
#
# script to do DQM nightly validation tests
# This is launched from the main script after the 
# main validaiton job is done.
# This builds DQM repo, runs on reco output, runs DQM histos and metrics
# and commits them.  It also commits the CPU and MEM metrics.
# Once this is launched, it is independent of the main script.
#


#
#
#
echo_date() {
    echo "[$(date)] $*" 
}

#
#
#
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

#
#
#
basic_setups() {
    echo_date "start setups"
    source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
    source $HOME/bin/authentication.sh
    klist
    voms-proxy-info --all
}

#
#
#
dqm_setups() {
    echo_date "start dqm setups"

    mkdir -p yesterday
    rm -f yesterday/*
    mv *.log *.txt nt* yesterday
    rm -rf build link DQM *.log .sconsign.dblite

    muse link $BUILD_DIR/Offline
    muse link $BUILD_DIR/Production
}

#
#
#
repo_build() {
    echo_date "start repo_build "

    if [ "$PWD" != "$DBUILD_DIR" ]; then
	echo "ERROR - repo_build was not in the dqm area!"
	return 1
    fi

    git clone -q https://github.com/Mu2e/DQM  || return 1

    git -C DQM show
    muse setup -1
    muse status
    muse build -j 5 --mu2eCompactPrint >& build.log
    RC=$?
    echo_date "finish repo_build with RC=$RC"
    echo "REPORT build RC=$RC"

    setup mu2efiletools

    printenv

    return $RC
}

#
#
#
metrics() {

    if [ "$PWD" != "$DBUILD_DIR" ]; then
	echo "ERROR - repo_build was not in the dqm area!"
	return 1
    fi

    NF=$( ls -1 $DATADIR/reco/art )
    if [ $NF -eq 0 ]; then
	echo "ERROR no reco data files found"
	return 1
    fi

    local TIME=$(date +%Y-%m-%dT00:01:00)

    find $DATADIR/reco/art -type f > in.txt

    # the file name for the DQM histos
    FAKESR=$(date +%y%m%d)
    local TFN="nts.mu2e.DQM_reco.valNightly_day_000.001000_${FAKESR}.root"

    mu2e -S in.txt -c DQM/fcl/dqmSimReco.fcl -T $TFN

    dqmMetrics $TFN

    klist
    voms-proxy-info --all

    dqmTool commit-value  \
	  --source "valNightly,reco,day,0" \
	  --start "$TIME" \
	  --value dqmMetrics.txt

    RC=$?
    echo "REPORT metrics commit RC=$RC"


    printJson.sh --no-parents $TFN > ${TFN}.json
    cp $TFN ${TFN}.json ${FTSPATH}/000

    RC=$?
    echo "REPORT DQM file copy RC=$RC"

    return 0
}

#
#
#
stats() {

  echo_date "starting dqm"

  local TIME=$(date +%Y-%m-%dT00:01:00)

  local RCD=0

  while read LL
  do 
      local TT=$(echo $LL | awk '{print $1}' )
      [ "$TT" != "LOGTIME" ] && continue

      local JJ=$(echo $LL | awk '{print $2}' )
      local CPU=$(echo $LL | awk '{print $4}' )
      local MEM=$(echo $LL | awk '{print $12}' )

      echo "valNightly,${JJ},day,0  ops,stats,CPU,${CPU},150.0,0"
      echo "valNightly,${JJ},day,0  ops,stats,MEM,${MEM},6.0,0"

      echo "ops,stats,CPU,${CPU},150.0,0" >  temp.txt
      echo "ops,stats,MEM,${MEM},6.0,0" >> temp.txt

      dqmTool commit-value \
	  --source "valNightly,${JJ},day,0" \
	  --start "$TIME" \
	  --value temp.txt

      RC=$?

      RCD=$(($RCD+$RC))

  done < $WEBREPORT

  echo "REPORT stats commit RC=$RCD"

  return $RCD

}

#
#
#
send_report() {
    grep REPORT $LOGFN | sed 's/REPORT//' > $DQMREPORT
    cat $DQMREPORT | mail -r valJobDqm \
	-s "valJobDqm $(date +%m/%d/%y )" \
	rlc@fnal.gov
#	rlc@fnal.gov
}


echo_date "start valJobSecondary"
cd $HOME/cron/val

WEBREPORT=valJobWeb.txt
DQMREPORT=valJobDqm.txt
rm -f $DQMREPORT
LOGFN=valJobDqm.log
BUILD_DIR=/mu2e/app/users/mu2epro/nightly/current
DBUILD_DIR=/mu2e/app/users/mu2epro/nightly/dqm
DATADIR=/pnfs/mu2e/persistent/users/mu2epro/valjob/$(date +%Y/%m/%d)
FTSPATH=/pnfs/mu2e/persistent/fts/global


basic_setups

# run builds and tests on the app disk
mkdir -p $DBUILD_DIR
safe_cd $DBUILD_DIR  || exit 1

dqm_setups
repo_build
RC=$?
[ $RC -ne 0 ] && exit 1

metrics

# return to source dir for the report
safe_cd $HOME/cron/val  || exit 1

stats

send_report

exit 0


