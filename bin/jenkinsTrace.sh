#!/bin/bash
#
# build a tagged version of TRACE in Jenkins system
# the following are defined as jenkins project parameters
# export PACKAGE_VERSION=v3_17_05
# TRACE is a noarch product, has no qualifiers
#


OS=`echo $label | tr "[A-Z]" "[a-z]"`

echo "[`date`] start $PACKAGE_VERSION $OS"
echo "[`date`] PWD"
pwd
echo "[`date`] directories"
rm -rf trace build products
mkdir -p build
mkdir -p products
export LOCAL_DIR=$PWD

echo "[`date`] ls of local dir"
ls -al *

echo "[`date`] source products common"
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
echo "[`date`] setup mu2e"
setup mu2e

echo "[`date`] rsync"
# where to install new products
export CETPKG_INSTALL=$LOCAL_DIR/products
# .upsfiles needs to be there
rsync -aur /cvmfs/mu2e.opensciencegrid.org/artexternals/.upsfiles $CETPKG_INSTALL
# max parallelism in build
export CETPKG_J=10

echo "[`date`] git clone"
# Make top level working directory, clone source and checkout tag
git clone https://github.com/art-daq/trace.git
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] checkout"
cd trace
git checkout -b work $PACKAGE_VERSION

cd $LOCAL_DIR/build

echo "[`date`] setup_for_development"
source ../trace/ups/setup_for_development
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] buildtool"
buildtool -i
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] buildtool RC=$RC"

PACKAGE_VERSION_DOT=`echo $PACKAGE_VERSION | sed -e 's/v//' -e 's/_/\./g' `
TBALL=trace-${PACKAGE_VERSION_DOT}-x86_64.tar.bz2

cd $LOCAL_DIR

tar -cj -C products -f $TBALL TRACE
RC=$?
[ $RC -ne 0 ] && exit $RC

mv $TBALL copyBack

echo "[`date`] ls"
ls -l *

echo "[`date`] normal exit"
