#! /bin/echo "You should be sourcing this file."
#
# Setup the Mu2e environment; this script does not setup
# any release of the Mu2e software.
#
# during transition to spack support gen2, an argument of "2"
# will setup gen2
#

# jump out if this has already been run
[ "$MU2E" ] && return 0

# where mu2e-managed products are (artexternals)
export MU2E=/cvmfs/mu2e.opensciencegrid.org

# magnetic field maps, data files for tests etc.
export MU2E_DATA_PATH=${MU2E}/DataFiles

OSID=$( source /etc/os-release 2> /dev/null ; echo $ID )
if [ "$OSID" == "scientific" ]; then
    export MU2E_OSNAME="sl7"
elif [ "$OSID" == "almalinux" ]; then
    export MU2E_OSNAME="al9"
    export UPS_OVERRIDE="-H Linux64bit+5.14-2.34-al9-3"
    export MU2E_SPACK=true
fi

# always redefine ups to point to artexternals version for consistency
source ${MU2E}/artexternals/setup

# make sure the mu2e path is in front of fermilab path
export PRODUCTS=`dropit -p $PRODUCTS -sf /cvmfs/fermilab.opensciencegrid.org/products/common/db`
export PRODUCTS=`dropit -p $PRODUCTS -sf /cvmfs/mu2e.opensciencegrid.org/artexternals`

# Make sure that subshells can see the UPS setup command.
export -f setup
export -f unsetup

# this is separate from above so that it can be set by the user on sl7
if [ "$MU2E_SPACK" ]; then
    source /cvmfs/mu2e.opensciencegrid.org/spackages/241207/spack/setup-env.sh
    source /cvmfs/mu2e.opensciencegrid.org/bin/smack.sh functions
    #source /cvmfs/mu2e.opensciencegrid.org/packages/setup-env.sh
    spack load git/q3orrja
    #spack load muse/di7thnq
    spack load muse/rfqcnx6
    source $MUSE_DIR/bin/museDefine.sh

    spack_load_current() { spack load $(spack_current.sh $1); }
    slc() { spack load $(spack_current.sh $1); }
    export -f spack_load_current slc
    export METACAT_SERVER_URL="https://metacat.fnal.gov:9443/mu2e_meta_prod/app"
    export METACAT_AUTH_SERVER_URL="https://metacat.fnal.gov:8143/auth/mu2e"
    export DATA_DISPATCHER_URL="https://metacat.fnal.gov:9443/mu2e_dd_prod/data"
    export DATA_DISPATCHER_AUTH_URL="https://metacat.fnal.gov:8143/auth/mu2e"
    export RUCIO_HOME="/cvmfs/mu2e.opensciencegrid.org/DataFiles/DataHandling"
    if [ "$GRID_USER" ]; then
        export RUCIO_ACCOUNT="$GRID_USER"
    else
        export RUCIO_ACCOUNT="$USER"
    fi
else
    setup git
    setup muse
fi

# add some Mu2e utility commands
export PATH=`dropit -p $PATH -sf /cvmfs/mu2e.opensciencegrid.org/bin`


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

pyenv() {
  source "/cvmfs/mu2e.opensciencegrid.org/bin/pyenv.sh"
}
