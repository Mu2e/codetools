#! /bin/bash
# script to build CRVTeststand repo and package for UPS
# will check the repo and create directories in default dir
#
# $1 = CRVTeststand tag to build
# $2 = Offline version to setup to define compiler switches
#      if missing, take current
#
#

CTAG="$1"
if [ -z "$CTAG" ]; then
    echo "ERROR - must provide a CRVTeststand tag"
    exit 1
fi

source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh
muse setup Offline $2
RC=$?
if [ $RC -ne 0 ]; then
    echo "ERROR - muse setup failed"
    exit 1
fi

git clone https://github.com/Mu2e/CRVTeststand  || exit 1

cd CRVTeststand || exit 1

echo "Checking out $CTAG ..."
git checkout -b build $CTAG || exit 1

make
RC=$?
if [ $RC -ne 0 ]; then
    echo "ERROR - make failed"
    exit 1
fi

FLAVOR=$(echo $SETUP_ROOT | awk '{print $4}')
ROOTSETUP=$(echo $SETUP_ROOT | awk '{print $1" "$2" "$3" "$4" "$7" "$8}')
#      setupRequired("gcc $GCC_VERSION")

mkdir -p upsd/CRVTeststand/$CTAG/ups
mkdir -p upsd/CRVTeststand/$CTAG/$FLAVOR
mkdir -p upsd/CRVTeststand/${CTAG}.version

rsync -aur CRVTeststand/* upsd/CRVTeststand/$CTAG/$FLAVOR

cat > upsd/CRVTeststand/$CTAG/ups/CRVTeststand.table <<EOL
File    = table
Product = CRVTeststand

Group:

  Flavor = Linux64bit+3.10-2.17
  Qualifiers =

  Common:
    Action = setup
      prodDir()
      setupEnv()
      envSet(\${UPS_PROD_NAME_UC}_VERSION, $CTAG)
      setupRequired("$ROOTSETUP")
      envSet( \${UPS_PROD_NAME_UC}_FQ_DIR, \${\${UPS_PROD_NAME_UC}_DIR}/\${UPS_PROD_FLAVOR} )
      pathPrepend(PATH, \${\${UPS_PROD_NAME_UC}_FQ_DIR})
      pathPrepend(PYTHONPATH, \$\${UPS_PROD_NAME_UC}_FQ_DIR/analysis/efficiency_demo )
      pathPrepend(PYTHONPATH, \$\${UPS_PROD_NAME_UC}_FQ_DIR/analysis/testbench )

End:

EOL

cat > upsd/CRVTeststand/${CTAG}.version/$FLAVOR <<EOL
FILE    = version
PRODUCT = CRVTeststand
VERSION = $CTAG

FLAVOR = $FLAVOR
QUALIFIERS =
  PROD_DIR = CRVTeststand/$CTAG
  UPS_DIR = ups
  TABLE_FILE = CRVTeststand.table


EOL

tar -cjf CRVTeststand-${CTAG}.bz2 -C upsd CRVTeststand/${CTAG} CRVTeststand/${CTAG}.version
