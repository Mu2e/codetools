#!/bin/bash

pyenvUsage() {
    cat << EOF

    Usage: muse activate ENV_NAME

    Activates a Mu2e Python environment (Pixi Pack Native).
    
    Available environments:
      • ana     - Standard analysis environment
      • rootana - Analysis environment with pyROOT support
    
    Parameters:
      ENV_NAME - Required: Environment name ('ana' or 'rootana')
    
    Examples:
      pyenv ana
      pyenv rootana

    See https://mu2ewiki.fnal.gov/wiki/Elastic_Analysis_Facility_(EAF)#Change_log for version info 

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
ENVNAME=$1
VERSION="2.7.0"  # Explicitly locked to version 2.7.0

# ---------------------------------------------------------------------
# SAFE CVMFS FALLBACK CHECK
# ---------------------------------------------------------------------
# If MU2E is empty/unset, default to the standard Open Science Grid mount point
if [ -z "$MU2E" ]; then
    export MU2E="/cvmfs/mu2e.opensciencegrid.org"
fi

# Define the absolute target directory on CVMFS
CONDA_PREFIX="${MU2E}/env/${ENVNAME}/${VERSION}"

# Verify the environment actually exists before attempting to load it
if [ ! -d "$CONDA_PREFIX" ]; then
    echo "ERROR - Mu2e Python environment directory not found!"
    echo "Path: $CONDA_PREFIX"
    return 1
fi

export pyenv_NAME="$ENVNAME"
export pyenv_VERSION="$VERSION"
export CONDA_PREFIX="$CONDA_PREFIX"

echo "Activating Mu2e Python environment: $ENVNAME $VERSION (Pixi-Pack layout)"

# =====================================================================
# INTEGRATED PATH CLEANING & COMMAND PROTECTION
# =====================================================================
setup_mu2e_python_env() {
    # Clean and prioritize PATH
    PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$CONDA_PREFIX" | tr '\n' ':' | sed 's/:$//')
    export PATH="$CONDA_PREFIX/bin:$PATH"
    
    # Clean and prioritize PYTHONPATH
    PYTHONPATH=$(echo "$PYTHONPATH" | tr ':' '\n' | grep -v "$CONDA_PREFIX" | tr '\n' ':' | sed 's/:$//')
    export PYTHONPATH="$CONDA_PREFIX/lib/python3.12/site-packages:$PYTHONPATH"
    
    # Clean and prioritize JUPYTER_PATH
    JUPYTER_PATH=$(echo "$JUPYTER_PATH" | tr ':' '\n' | grep -v "$CONDA_PREFIX" | tr '\n' ':' | sed 's/:$//')
    export JUPYTER_PATH="$CONDA_PREFIX/share/jupyter/kernels:$JUPYTER_PATH"

    # Graphics, UI & Fonts
    export QT_QPA_PLATFORM_PLUGIN_PATH="$CONDA_PREFIX/lib/qt6/plugins/platforms"
    export FONTCONFIG_FILE="$CONDA_PREFIX/etc/fonts/fonts.conf"

    # SSL Cert allocations for locked down network nodes
    export GIT_SSL_CAINFO="$CONDA_PREFIX/ssl/cacert.pem"
    export SSL_CERT_FILE="$CONDA_PREFIX/ssl/cacert.pem"
    export CURL_CA_BUNDLE="$CONDA_PREFIX/ssl/cacert.pem"

    # Terminal UI and ROOT system roots
    export TERMINFO="$CONDA_PREFIX/share/terminfo"
    export CONDA_BUILD_SYSROOT="$CONDA_PREFIX/x86_64-conda-linux-gnu/sysroot"

    # Logging Suppressions
    export TF_CPP_MIN_LOG_LEVEL=3
    export ZFIT_DISABLE_TF_WARNINGS=1
    
    # Dynamic Library Binding
    LD_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -v "$CONDA_PREFIX" | tr '\n' ':' | sed 's/:$//')
    export LD_LIBRARY_PATH="$CONDA_PREFIX/lib:$LD_LIBRARY_PATH"
}

# Run the runtime path-cleanup sequence immediately on sourcing
setup_mu2e_python_env

# Inject hidden protective command interception wrappers
for cmd in python pip jupyter conda mamba; do
    eval "${cmd}() {
        setup_mu2e_python_env
        command ${cmd} \"\$@\"
    }"
    export -f "$cmd"
done

export -f setup_mu2e_python_env
# =====================================================================

# Setup deactivate function safely
deactivate() {
    # Since there's no CVMFS script to undo changes, we strip out the paths manually
    PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$CONDA_PREFIX" | tr '\n' ':' | sed 's/:$//')
    PYTHONPATH=$(echo "$PYTHONPATH" | tr ':' '\n' | grep -v "$CONDA_PREFIX" | tr '\n' ':' | sed 's/:$//')
    JUPYTER_PATH=$(echo "$JUPYTER_PATH" | tr ':' '\n' | grep -v "$CONDA_PREFIX" | tr '\n' ':' | sed 's/:$//')
    LD_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -v "$CONDA_PREFIX" | tr '\n' ':' | sed 's/:$//')
    
    export PATH PYTHONPATH JUPYTER_PATH LD_LIBRARY_PATH

    # Tear down function wrappers completely to restore clean system shell state
    for cmd in python pip jupyter conda mamba; do
        unset -f "$cmd"
    done
    unset -f setup_mu2e_python_env
    
    # Reset tracking environment variables
    unset pyenv_NAME
    unset pyenv_VERSION
    unset CONDA_PREFIX
    
    echo "Deactivated Mu2e Environment."
    unset -f deactivate
}

echo "Run 'deactivate' to exit the environment" 
return 0