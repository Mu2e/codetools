#!/bin/bash
# Ryunosuke O'Neil, 2020
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk
# sets up job environment and calls the job.sh script in the relevant directory

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export JENKINS_TESTS_DIR="$DIR/github/jenkins_tests"
export CLANGTOOLS_UTIL_DIR="$DIR/../clangtools_utilities"
export TESTSCRIPT_DIR="$JENKINS_TESTS_DIR/$1"
export REQUIRED_BUILD_REPOS_SHORT=("Offline" "Production")

# if the PR is trying to merge into this branch, make sure all other repos
# in the build are set up in this branch by default
BRANCHNAMES_MUST_MATCH="Mu2eII_SM21"

cd "$WORKSPACE" || exit 1;


function check_set() {
    if [ -z "$1" ]; then
        return 1; # not set!
    fi

    return 0;
}

echo "Checking we're in the expected Jenkins environment...";

check_set $REPOSITORY || exit 1;
check_set $PULL_REQUEST || exit 1;
check_set $COMMIT_SHA || exit 1;
check_set $MASTER_COMMIT_SHA || exit 1;

echo "OK!"


# clean workspace from previous build 
echo "Delete files in workspace from previous builds (not directories)"
rm $WORKSPACE/* # removes files only - we only expect folders to exist in the workspace at the start of the build.
rm $WORKSPACE/.sconsign.dblite
rm -rf $WORKSPACE/build # this shouldn't be hanging around either
echo "Workspace now:"
ls -lah
echo ""
echo ""

echo "Bootstrapping job $1..."


JOB_SCRIPT="${TESTSCRIPT_DIR}/job.sh"

if [ ! -f "$JOB_SCRIPT" ]; then
    echo "Fatal error running job type $1 - could not find $JOB_SCRIPT."
    exit 1;
fi

echo "Setting up job environment..."


rm -rf *.log *.md *.patch > /dev/null 2>&1

function print_jobinfo() {
    echo "[`date`] print_jobinfo"
    echo "[`date`] printenv"
    printenv

    echo "[`date`] df -h"
    df -h

    echo "[`date`] quota"
    quota -v

    echo "[`date`] PWD"
    pwd
    export LOCAL_DIR=$PWD

    echo "[`date`] ls of local dir at start"
    ls -al

    echo "[`date`] cpuinfo"
    cat /proc/cpuinfo | head -30

}

function setup_cmsbot() {
    export CMS_BOT_DIR="$WORKSPACE/CI"

    [ -d "$HOME/mu2e-gh-bot-venv/" ] || python3 -m venv $HOME/mu2e-gh-bot-venv/
    source $HOME/mu2e-gh-bot-venv/bin/activate
    CMS_BOT_VENV_SOURCED=1

    python --version

    if [ ! -d ${CMS_BOT_DIR} ]; then
        (
            cd "$WORKSPACE"
            git clone git@github.com:Mu2e/CI
        )
    else
        (
            cd ${CMS_BOT_DIR}
            # make sure we don't try to use the old "master" branch, in favor
            # of "main"
            if [[ "$(git rev-parse --abbrev-ref HEAD)" == *"master"* ]]; then
                git fetch
                git checkout main
                git pull
            fi
            git reset --hard HEAD
            git fetch; 
            git pull
            cd -
        )
    fi
    pip install -U -r ${CMS_BOT_DIR}/requirements.txt
    pip freeze
}

function cmsbot_report() {
    if [ "${CMS_BOT_VENV_SOURCED}" -ne 1 ]; then
        CMS_BOT_VENV_SOURCED=1
        source $HOME/mu2e-gh-bot-venv/bin/activate
    fi
    ${CMS_BOT_DIR}/comment-github-pullrequest -r ${REPOSITORY} -p ${PULL_REQUEST} --report-file $1
}

function cmsbot_report_test_status() {
    if [ "${CMS_BOT_VENV_SOURCED}" -ne 1 ]; then
        CMS_BOT_VENV_SOURCED=1
        source $HOME/mu2e-gh-bot-venv/bin/activate
    fi

    ${CMS_BOT_DIR}/report-test-status \
        --repository ${REPOSITORY} \
        --pullrequest ${PULL_REQUEST} \
        --commit "${COMMIT_SHA}" \
        --test-name "$1" \
        --test-state "$2" \
        --message "$3" \
        --url "$4"
}

function cmsbot_write_pr_base() {
    # args: $1 is repo, $2 is pr number, $3 is the sha file name
    #       $4 is optional; if provided, it determines whether to write the
    #       base branch name instead of the commit sha. If not provided, 
    #       defaults to writing the commit sha.
    # example: cmsbot_write_pr_base Mu2e/Offline 581 repoOffline_pr581_baseSha.txt
    # example: cmsbot_write_pr_base Mu2e/Offline 581 repoOffline_pr581_baseName.txt True
    # That "True" is just a string to bash, but gets passed to Python, which expects a boolean
    if [ "${CMS_BOT_VENV_SOURCED}" -ne 1 ]; then
        CMS_BOT_VENV_SOURCED=1
        source $HOME/mu2e-gh-bot-venv/bin/activate
    fi
    justName=${4:-False}
    ${CMS_BOT_DIR}/get-pr-base-sha -r $1 -p $2 -f $3 -j $justName
}


function setup_build_repos() {
    # setup_build_repos Mu2e/Offline if you are testing Offline
    # setup_build_repos Mu2e/Production if you are testing Production
    export REPO=$(echo $1 | sed 's|^.*/||')
    export REPO_FULLNAME=$1
    base_branch=main
    # get the name of the branch this PR is requesting to merge into
    branchFileName="repo${REPO}_pr${PULL_REQUEST}_baseBranch.txt"
    cmsbot_write_pr_base $REPO_FULLNAME $PULL_REQUEST $branchFileName True || echo "Failed to retrieve base branch name for repo ${REPO_FULLNAME} PR ${PULL_REQUEST}"
    if [ -f $branchFileName ]; then
        base_branch=$(cat $branchFileName)
    fi
    (
        # clean up any previous builds
        rm -rf $REPO .sconsign.dblite build "${REQUIRED_BUILD_REPOS_SHORT[@]}"
        # clone all the required repos
        for reqrepo in "${REQUIRED_BUILD_REPOS_SHORT[@]}";
        do
            git clone "https://github.com/Mu2e/${reqrepo}"
            if [ ${base_branch} == ${BRANCHNAMES_MUST_MATCH} ]; then
                (
                    cd $reqrepo
                    git fetch origin ${base_branch} || echo "Failed to fetch branch ${base_branch} of repo Mu2e/${reqrepo}"
                    git checkout ${base_branch}  || echo "Failed to checkout branch ${base_branch} of repo Mu2e/${reqrepo}"
                )
            fi
        done
        # make sure we got our PR repo
        if [ ! -d "${REPO}" ]; then
            git clone "https://github.com/$REPO_FULLNAME"
        fi

        cd $REPO

        git config user.email "you@example.com"
        git config user.name "Your Name"

        git fetch origin pull/${PULL_REQUEST}/head:pr${PULL_REQUEST}
    )

}



echo "Running job now."

print_jobinfo

(
    source $JOB_SCRIPT
)
JOB_STATUS=$?

echo "Job finished with status $JOB_STATUS."
exit $JOB_STATUS
