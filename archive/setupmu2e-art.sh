#! /bin/echo "You should be sourcing this file."
#
# Setup the Mu2e environment; this script does not setup
# any release of the Mu2e software.
#
# This file is sourced directly or as part of "setup mu2e"
#

# where mu2e-managed products are (artexternals)
export MU2E=/cvmfs/mu2e.opensciencegrid.org

# magnetic field maps, data files for tests etc.
export MU2E_DATA_PATH=${MU2E}/DataFiles

# always redefine ups to point to artexternals version for consistency
source ${MU2E}/artexternals/setup

# make sure the mu2e path is in front of fermilab path
export PRODUCTS=`dropit -p $PRODUCTS -sf /cvmfs/fermilab.opensciencegrid.org/products/common/db`
export PRODUCTS=`dropit -p $PRODUCTS -sf /cvmfs/mu2e.opensciencegrid.org/artexternals`

# Make sure that subshells can see the UPS setup command.
export -f setup
export -f unsetup

# add some Mu2e utility commands
export PATH=`dropit -p $PATH -sf /cvmfs/mu2e.opensciencegrid.org/bin`

# force use of the current default UPS git
setup git

# setup Muse for convenience
setup muse

# Access to Mu2e cvs
export CVSROOT=mu2ecvs@cdcvs.fnal.gov:/cvs/mu2e
export CVS_RSH=/usr/bin/ssh

# Needed for ifdh
export EXPERIMENT=mu2e

# Needed for sam_web_client
export SAM_EXPERIMENT=mu2e

# Needed for jobsub_client
export JOBSUB_GROUP=mu2e

# make sure the default man paths are included (path starts with ":")
[ "${MANPATH:0:1}" != ":" ] && export MANPATH=":"$MANPATH

