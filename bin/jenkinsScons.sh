#!/bin/bash
#
# build a tagged version of scons in Jenkins system
# the following are defined as jenkins project parameters
# export PACKAGE_VERSION=v4_4_0 # scons source version
# export PACKAGE_SUBVERSION=""  # or "a" to be appended to the ups version
# export PYTHON_VERSION=v3_9_15 # python to install against
# to run locally, define these in the environment first
# the source code will be downloaded from sourceforge
#

echo "[$(date)] starting"
echo "PACKAGE_VERSION=$PACKAGE_VERSION="
echo "PACKAGE_SUBVERSION=$PACKAGE_SUBVERSION"
echo "PYTHON_VERSION=$PYTHON_VERSION"

mkdir -p copyBack
mkdir -p scons_build
rm -rf copyBack/* scons_build/*

if [ ! "$PACKAGE_VERSION" ]; then
    echo "error - required PACKAGE_VERSION was not set"
    exit 1
fi

if [ ! "$PYTHON_VERSION" ]; then
    echo "error - required PYTHON_VERSION_TAG was not set"
    exit 1
fi

VERSION=${PACKAGE_VERSION}${PACKAGE_SUBVERSION}
OWD=$PWD

echo "[$(date)] will build scons $VERSION with python $PYTHON_VERSION"

cd scons_build || exit 1

source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
setup python $PYTHON_VERSION
RC=$?
if [ $RC -ne 0 ]; then
    echo "error - failed to setup python version $PYTHON_VERSION"
    exit 1
fi

# like 4.4.0
DOTV=$(echo $PACKAGE_VERSION | tr -d v | tr _ . )

echo "[$(date)] pip install $DOTV"

pip install scons==$DOTV --target=$PWD
RC=$?
if [ $RC -ne 0 ]; then
    echo "error - pip install failed with RC=$C"
    exit 1
fi

# like python3.9
PMAJOR=python$(echo $PYTHON_VERSION | tr "v_" "  " | awk '{print $1"."$2}' )

echo "[$(date)] rsync python files"

mkdir -p scons/$VERSION/lib/$PMAJOR/site-packages
rsync -r bin scons/$VERSION
rsync -r SCons scons/$VERSION/lib/$PMAJOR/site-packages

echo "[$(date)] rsync man files"

mkdir -p scons/$VERSION/man/man1
rsync -r scons.1      scons/$VERSION/man/man1
rsync -r sconsign.1   scons/$VERSION/man/man1
rsync -r scons-time.1 scons/$VERSION/man/man1

mkdir -p scons/$VERSION/ups

echo "[$(date)] make table file"

cat > scons/$VERSION/ups/scons.table <<EOL
File=Table
Product=scons
#*************************************************
# Starting Group definition
Group:

Flavor=ANY


Common:
   Action=setup
    setupRequired( python $PYTHON_VERSION )
    proddir()
    setupenv()
    # add the lib directory to LD_LIBRARY_PATH
    prodDir(_LIB, \${UPS_PROD_QUALIFIERS}/lib)
    # add the bin directory to the path if it exists
    pathPrepend(PATH, \${UPS_PROD_DIR}/bin)
    envSet(\${UPS_PROD_NAME_UC}_LIB_DIR, \${\${UPS_PROD_NAME_UC}_LIB}/\${PYTHON_LIBDIR}/site-packages)
    pathPrepend(PYTHONPATH, \${\${UPS_PROD_NAME_UC}_LIB_DIR})
    pathPrepend(MANPATH, \${UPS_PROD_DIR}/man)

#     envPrepend(PYTHONPATH, \${\${UPS_PROD_NAME_UC}_FQ_DIR}/lib/\${PYTHON_LIBDIR}/site-packages)
#      pathPrepend(PATH, \${\${UPS_PROD_NAME_UC}_FQ_DIR}/bin)


    # requirements
End:
# End Group definition
#*************************************************
EOL

echo "[$(date)] make version file"

mkdir -p scons/${VERSION}.version
cat > scons/${VERSION}.version/NULL <<EOL
FILE = version
PRODUCT = scons
VERSION = $VERSION

#*************************************************
#
FLAVOR = NULL
QUALIFIERS =
  PROD_DIR = scons/$VERSION
  UPS_DIR = ups
  TABLE_DIR = ups
  TABLE_FILE = scons.table
EOL

tar -cjf ../copyBack/scons-${VERSION}.bz2 scons
cd $OWD

echo "[$(date)] final ls"
ls -l
ls -l *


exit 0
