#!/bin/bash
#
# Script to activate a Mu2e Python environment from /cvfms 
#

pyenvUsage() {
    cat << EOF

    Usage: muse activate ENV_NAME [VERSION]

    Activates a Mu2e Python environment.
    
    Available environments:
      • ana     - Standard analysis environment
      • rootana - Analysis environment with pyROOT support
    
    Parameters:
      ENV_NAME - Required: Environment name ('ana' or 'rootana')
      VERSION  - Optional: Environment version (default: 'current')
    
    Examples:
      pyenv ana
      pyenv rootana 1.2.0
      
    The first example runs:
      source /cvmfs/mu2e.opensciencegrid.org/env/ana/current/bin/activate

    See https://mu2ewiki.fnal.gov/wiki/Elastic_Analysis_Facility_(EAF)#Change_log for version info 

    <command options>
        -h, --help  : print usage

EOF
    return
}

# Show usage information if -h or no args
if [[ "$1" == "-h" || "$1" == "--help" || "$1" == "help" || $# -eq 0 ]]; then
    pyenvUsage
    return 0
fi

# Unset the help function 
unset -f pyenvUsage 

# Parse command line arguments
ENVNAME=""
VERSION=""

# Get the environment name and version from args
ENVNAME=$1
VERSION=${2:-current}  # Use 'current' as default if $2 is not provided

# Path to the activate/deactive scripts
SCRIPT_PATH="${MU2E}/env/${ENVNAME}/${VERSION}/bin"
ACTIVATE_PATH="${SCRIPT_PATH}/activate"
DEACTIVATE_PATH="${SCRIPT_PATH}/deactivate"

# Export variables so they're available to child processes (deactivate)
export pyenv_NAME="$ENVNAME"
export pyenv_VERSION="$VERSION"
export pyenv_SCRIPT_PATH="$SCRIPT_PATH"

# Check if the activate script exists
if [ ! -f "$ACTIVATE_PATH" ]; then
    echo "ERROR - activate script not found!"
    echo "Path: $ACTIVATE_PATH"
    return 1
fi

# Activate the environment
echo "Activating Mu2e Python environment: $ENVNAME $VERSION"
source "$ACTIVATE_PATH"

# Setup deactivate 
deactivate() {
    if [ -f "$DEACTIVATE_PATH" ]; then
        source "$DEACTIVATE_PATH"
    else
        echo "WARNING: deactivate script not found at $DEACTIVATE_PATH"
        # Fall back to Python's deactivate if available
        if type python_deactivate >/dev/null 2>&1; then
            python_deactivate
        fi
    fi
    
    # Unset environment variables
    unset pyenv_NAME
    unset pyenv_VERSION
    unset pyenv_SCRIPT_PATH
    
    # Unset this function
    unset -f deactivate
}

echo "Run 'deactivate' to exit the environment" 

# Return success
return 0