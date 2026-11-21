#!/usr/bin/bash
#
# Script to create a spack workdir with prof and debug builds, using and driven by pre-existing source repo clones found in the specified directory
#
usage() {
  echo "Usage: $0
  [ --basedir 'BASEDIR' (optional) Base directory. Will use $PWD if not set ]
  [ --repodir 'REPODIR' (optional) Directory under 'basedir' where the Mu2e git repos have been checked out. Will use 'Repos' if not set ]
  [ --spackdir 'SPACKDIR' (optional) Directory under 'basedir' to create the spack workdir in. Will use 'SpackWorkdir' if not set ]
  [ --env 'environment' (optional) Environment to build. This can be entered multiple times to create multiple envs. By default both prof and debug will be created ]
  [ --extend (optional) Extend environments or repos to an existing spack workdir, default false ]
  [ --build (optional) Build the environments after creating the workdir, default false ]
  [ --dryrun (optional) Print what this command woudl do, default false ]
  "
}

exit_abnormal() {
  usage
  exit 1
}

cleanup() {
  # cleanup directory in case of failure
#  rm -rf $BASEDIR/$SPACKDIR
  exit 3
}

develop () {
  local BASEDIR=$1
  local REPODIR=$2
  local ENV=$3
  local DEVREPO=$4
  if [[ ! -d ${BASEDIR}/${REPODIR}/${DEVREPO} ]]; then
    echo "Mu2e repo ${DEVREPO} not found under ${BASEDIR}/${REPODIR}; make sure that is checked out before running this script again"
    return 2
  fi
  ENVOPT=""
  if [[ -f ${BASEDIR}/${REPODIR}/${DEVREPO}/CMakeLists.txt && "${ENV}" == "debug" ]]; then
    ENVOPT="build_type=Debug"
  fi
  local SPACKAGE=`spackage ${DEVREPO}`
  SLIST=`spack list ${SPACKAGE}`
  if [[ ! ${SLIST} ]]; then
    echo "No spack package found for ${DEVREPO}; skipping"
    return 1
  fi
#  echo "mapping ${DEVREPO} to ${SPACKAGE}"
  if [[ `spack find ${SPACKAGE} 2> /dev/null` ]]; then
    spack rm ${SPACKAGE}
  fi
  spack add ${SPACKAGE}@main $ENVOPT
  if [ ! $? -eq 0 ]; then
   return 3
  fi
  spack develop -p ${BASEDIR}/${REPODIR}/${DEVREPO} ${SPACKAGE}@main
  if [ ! $? -eq 0 ]; then
    return 3
  fi
  return 0
}

function spackage {
  declare -A SPACKMAP=(["Production"]="production" ["KinKal"]="kinkal" ["EventNtuple"]="event-ntuple" ["ArtAnalysis"]="art-analysis")
  GITREPO=${1}
  SPACKAGE=${GITREPO}
  if [ -v SPACKMAP[$GITREPO] ]; then
    SPACKAGE=${SPACKMAP[${GITREPO}]}
  fi
  echo $SPACKAGE
}

BASEDIR=`pwd`
REPODIR="Repos"
SPACKDIR="SpackWorkdir"
ENVS=()
BUILDIT=false
EXTEND=false
DRYRUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --basedir)
      BASEDIR="$2"
      shift 2
      ;;
    --repodir)
      REPODIR="$2"
      shift 2
      ;;
    --spackdir)
      SPACKDIR="$2"
      shift 2
      ;;
    --env)
      ENVS+=("$2")
      shift 2
      ;;
    --dryrun)
      DRYRUN=true
      shift 1
      ;;
    --extend)
      EXTEND=true
      shift 1
      ;;
    --build)
      BUILDIT=true
      shift 1
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit_abnormal
      ;;
  esac
done

# sanity tests
if [[ ! -d ${BASEDIR} ]]; then
  echo "Base directory ${BASEDIR} doesnt exist!"
  exit 1
fi
cd ${BASEDIR}
if [[ ! -d ${BASEDIR}/${REPODIR} ]]; then
  echo "Repo directory ${REPODIR} doesnt exist!"
  exit 1
fi

if [[ ${EXTEND} -ne "true" ]]; then
  if [[ -d ${BASEDIR}/${SPACKDIR}  ]]; then
    echo "Spack directory ${SPACKDIR} already exists! Move it or remove it first"
    exit 1
  fi
else
  if [[ ! -d ${BASEDIR}/${SPACKDIR}  ]]; then
    echo "Spack directory ${SPACKDIR} doesn't exist so can't be extended"
    exit 1
  fi
fi

if [ ${#ENVS[@]} -eq 0 ]; then
  ENVS=("prof" "debug")
fi

# find repos to develop
DEVREPOS=()
RDIRS=("${BASEDIR}/${REPODIR}"/*/)
for RDIR in "${RDIRS[@]}"; do
  DEVREPOS+=($(basename "$RDIR"))
done

echo "Creating spack workdir ${SPACKDIR} in bsae directory ${BASEDIR} with environments ${ENVS[@]} with repos ${DEVREPOS[@]} from ${REPODIR} "
if [[ ${DRYRUN} == "true" ]]; then
  echo "Dryrun exit"
  exit 0
fi

# the following defines the spack and smack commands
source /cvmfs/mu2e.opensciencegrid.org/setupmu2e-art.sh

if [[ ${EXTEND} -ne "true" ]]; then
  mkdir ${SPACKDIR}
  smack subspack ${SPACKDIR}
fi

cd ${SPACKDIR}
for ENV in "${ENVS[@]}"; do
  if [[ ! -d ${ENV} ]]; then
    echo "Creating environment ${ENV}"
    smack subenv ${ENV}
    if [ ! $? -eq 0 ]; then
      echo "Failed to create env ${ENV}: aborting"
      return 1
    fi
  fi
done
# the following can only be sourced AFTER the subenvs are created
source setup-env.sh
for ENV in "${ENVS[@]}"; do
  echo "Setting up environment ${ENV}"
  spack env activate ${ENV}
  for DEVREPO in "${DEVREPOS[@]}"; do
    develop ${BASEDIR} ${REPODIR} ${ENV} ${DEVREPO}
    if [ $? -eq 0 ]; then
      echo "Adding ${DEVREPO} for development"
    # add a link to this directory if needed
      if [[ ! -L ${DEVREPO} ]]; then
        ln -s ${BASEDIR}/${REPODIR}/${DEVREPO} ./
      fi
    elif [ $? -gt 1 ];then
      echo "Failed to add ${DEVREPO} for development"
    fi
  done
  spack concretize -f >& concretize_${ENV}.log
  spack env deactivate
done

if [[ ${BUILDIT} == "true" ]]; then
  for ENV in "${ENVS[@]}"; do
    echo "Building env ${ENV}"
    spack env activate ${ENV}
    spack install >& install_${ENV}.log
    spack env deactivate
  done
fi
