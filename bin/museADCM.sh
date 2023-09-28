#! /bin/bash
#
#
#

usage() {

cat <<EOF

museADCM [install|build]

   This script is to help with bulding artdaq_core_mu2e locally
in a muse environment. It will create a local build directory
\$MUSE_WORK_DIR/adcm and build ADCM there.  It will UPS install
the result into the Muse-aware directory \$MUSE_WORK_DIR/artexternals.
   Once it is installed there, you will need to re-"muse setup"
to get it in your path.  The code will be checked out to the tag
that is in the Muse envset so at first build it should be identical
to the envset.  You can them edit the code and run this script with
the "build" command to rebuild and re-install in artexternals.
   To return to work in this area, simply "muse setup" in the
working area.
   Please note the script installs an ADCM with the same version as the
current official envset version, and simply puts this version first
in the path, so there is a potential for confusion concerning which
code is active.  You can use "ups active | grep artdaq" to confirm
which build is in your paths.

install:
   create needed directories, checkout the repo
   and also run the build and UPS install

build:
   run the code build and UPS install


EOF
}


install_adcm() {
    if [ ! "$MUSE_WORK_DIR" ]; then
        echo "Muse is not setup, make a build area and 'muse setup'"
        return 1
    fi
    cd $MUSE_WORK_DIR

    echo "creating \$MUSE_WORK_DIR/artexternals"
    mkdir -p artexternals
    # .upsfiles needs to be there
    rsync -ar /cvmfs/mu2e.opensciencegrid.org/artexternals/.upsfiles artexternals
    # build the product here

    echo "creating \$MUSE_WORK_DIR/adcm/build"
    mkdir -p adcm/build

    echo "checking out artdaq_core_mu2e $ARTDAQ_CORE_MU2E_VERSION in \$MUSE_WORK_DIR/adcm"
    (
        cd $MUSE_WORK_DIR/adcm
        git clone  https://github.com/Mu2e/artdaq_core_mu2e || exit 1
        cd artdaq_core_mu2e
        git checkout -b work $ARTDAQ_CORE_MU2E_VERSION || exit 1
    )
    # checkout a tag or edit as needed
    RC=$?
    echo "RC=$RC"
    [ $? -ne 0 ] && return 1
    return 0
}

build_adcm() {
    if [ ! "$MUSE_WORK_DIR" ]; then
        echo "Muse is not setup, make a build area and 'muse setup'"
        return 1
    fi

    unsetup cetmodules
    # the product will end up here
    export CETPKG_INSTALL=$MUSE_WORK_DIR/artexternals
    echo "build in \$MUSE_WORK_DIR/adcm/build"
    echo "install UPS product in \$MUSE_WORK_DIR/artexternals"
    (
        cd $MUSE_WORK_DIR/adcm/build
        [ "$MUSE_BUILD" == "debug" ] && FLAG="-d" || FLAG="-p"
        source ../artdaq_core_mu2e/ups/setup_for_development $FLAG ${MUSE_COMPILER_E}:${MUSE_ART}
        buildtool -i
    )
    return $?
}




MODE="$1"

if [[ "$MODE" == "-h" || "$MODE" == "--help" || "$MODE" == "help" ]]; then
    usage
elif [ "$MODE" == "install" ]; then
    install_adcm || exit 1
    build_adcm || exit 1
    echo <<EOF

*************************************************************
artdaq_core_mu2e is not install locally.  In order to include
in you paths, start a new process and run "muse setup" again
*************************************************************

EOF

elif [ "$MODE" == "build" ]; then
    build_adcm || exit 1
else
    echo "unknown or missing MODE argument"
    usage
    exit 1
fi


exit 0

# build a tagged version of artdaq_core_mu2e in Jenkins system
# the following are defined by the project:
# export BUILDTYPE=prof
# export label=SLF6
# the following are defined as jenkins project parameters
# export PACKAGE_VERSION=v1_02_00a
# export COMPILER=e14
# export ART_VERSION=s58
# export PYTHON_VERSION_TAG=py3
# to run locally, define these in the environment first
#



OS=`echo $label | tr "[A-Z]" "[a-z]"`

echo "[`date`] start $PACKAGE_VERSION $COMPILER $ART_VERSION $BUILDTYPE $OS"
echo "[`date`] PWD"
pwd
echo "[`date`] directories"
rm -rf artdaq_core_mu2e build products
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
git clone https://github.com/Mu2e/artdaq_core_mu2e.git
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] checkout"
cd artdaq_core_mu2e
git checkout -b work $PACKAGE_VERSION

cd $LOCAL_DIR/build

FLAG="-p"
[ "$BUILDTYPE" == "debug" ] && FLAG="-d"
echo "[`date`] setup_for_development $FLAG ${COMPILER}:${ART_VERSION}${PFLAG}"
source ../artdaq_core_mu2e/ups/setup_for_development $FLAG ${COMPILER}:${ART_VERSION}${PFLAG}
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] buildtool"
buildtool -i
RC=$?
[ $RC -ne 0 ] && exit $RC

echo "[`date`] buildtool RC=$RC"

PACKAGE_VERSION_DOT=`echo $PACKAGE_VERSION | sed -e 's/v//' -e 's/_/\./g' `
PYTHON_TAG=""
[ -n "$PYTHON_VERSION_TAG" ] && PYTHON_TAG="-$PYTHON_VERSION_TAG"
TBALL=artdaq_core_mu2e-${PACKAGE_VERSION_DOT}-${OS}-x86_64-${COMPILER}-${ART_VERSION}-${BUILDTYPE}${PYTHON_TAG}.tar.bz2

cd $LOCAL_DIR

tar -cj -C products -f $TBALL artdaq_core_mu2e
RC=$?
[ $RC -ne 0 ] && exit $RC

mv $TBALL copyBack

echo "[`date`] ls"
ls -l *

echo "[`date`] normal exit"
