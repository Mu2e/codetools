#!/bin/bash
# Helenka Casler, 2021
# Contact: HCasler on GitHub

# add a row to the test statuses
function append_report_row() {
    MU2E_POSTTEST_STATUSES="${MU2E_POSTTEST_STATUSES}
| $1 | $2 | $3 |"
}

# Checks out the correct branches and revisions of the code, performs all merges.
# At the end of this, the repositories should be in the right conditions to build 
# the code and run the tests.
function prepare_repositories() {
    cd ${WORKSPACE}/${REPO}
    if [ $? -ne 0 ]; then 
        return 1
    fi
    echo "starting prepare_repositories in $PWD"
    echo "NO_MERGE=$NO_MERGE"
    echo "REPO=$REPO"
    echo "TEST_WITH_PR=$TEST_WITH_PR"
    if [ "${NO_MERGE}" = "1" ]; then
        echo "[$(date)] Mu2e/$REPO - Checking out PR HEAD directly"
        git checkout ${COMMIT_SHA} #"pr${PULL_REQUEST}"
        git log -1
        append_report_row "checkout" ":white_check_mark:" "Checked out ${COMMIT_SHA} without merging into base branch"
    else
        echo "[$(date)] Mu2e/$REPO - Checking out latest commit on base branch, which is ${MASTER_COMMIT_SHA}"
        git checkout ${MASTER_COMMIT_SHA}
        git log -1
    fi

    if [ "${TEST_WITH_PR}" != "" ]; then
        # comma separated list

        for pr in $(echo ${TEST_WITH_PR} | sed "s/,/ /g")
        do
            # if it starts with "#" then it is a PR in $REPO.
            if [[ $pr = \#* ]]; then
                REPO_NAME="$REPO"
                THE_PR=$( echo $pr | awk -F\# '{print $2}' )
                cd $WORKSPACE/$REPO
            elif [[ $pr = *\#* ]]; then
                # get the repository name
                REPO_NAME=$( echo $pr | awk -F\# '{print $1}' )
                echo "in second condition of test with"
                echo "REPO_NAME=$REPO_NAME"
                if [ "$REPO_NAME" == "mu2e-trig-config" ]; then
                    echo "adjusting mu2e-trig-config name"
                    REPO_NAME="mu2e_trig_config"
                fi
                THE_PR=$( echo $pr | awk -F\# '{print $2}' )
                echo "THE_PR=$THE_PR"
                # check it exists, and clone it into the workspace if it does not.
                if [ ! -d "$WORKSPACE/$REPO_NAME" ]; then
                    (
                        cd $WORKSPACE
                        echo "cloning test wth $REPO_NAME into $PWD"
                        git clone https://github.com/Mu2e/${REPO_NAME}.git ${REPO_NAME} || exit 1
                    )
                    if [ $? -ne 0 ]; then 
                        append_report_row "test with" ":x:" "Mu2e/${REPO_NAME} git clone failed"
                        return 1
                    fi
                fi
                # change directory to it
                cd $WORKSPACE/$REPO_NAME || exit 1
            else
                # ???
                return 1
            fi

            git config user.email "you@example.com"
            git config user.name "Your Name"
            git fetch origin pull/${THE_PR}/head:pr${THE_PR}

            # get the base ref commit sha for the test-with PR, but ONLY if it's in a different repo than the "overall" PR we're testing.
            if [ ${REPO_NAME} != ${REPO} ]; then
                SHA_FILE_NAME="repo${REPO_NAME}_pr${THE_PR}_baseSha.txt"
                cmsbot_write_pr_base Mu2e/$REPO_NAME $THE_PR $SHA_FILE_NAME || echo "Failed to retrieve base branch commit sha for repo ${REPO_NAME} PR ${THE_PR}"
                if [ -f $SHA_FILE_NAME ]; then
                    THE_BASE_SHA=$(cat $SHA_FILE_NAME)
                    echo "Checking out commit ${THE_BASE_SHA} on repo ${REPO_NAME} before merging PR ${THE_PR}"
                    git checkout ${THE_BASE_SHA} || echo "Failed to checkout commit ${THE_BASE_SHA}, default is to merge into main"
                    git log -1
                else
                    echo "No base commit sha file written for ${REPO_NAME}#${THE_PR}, default base is main branch"
                    append_report_row "test with" ":x:" "Failed to retrieve request base branch commit sha for Mu2e/${REPO_NAME}#${THE_PR}, default is to merge into main"
                fi
            fi

            echo "[$(date)] Merging PR ${REPO_NAME}#${THE_PR} into ${REPO_NAME} as part of this test."

            THE_COMMIT_SHA=$(git rev-parse pr${THE_PR})

            # Merge it in
            git merge --no-ff pr${THE_PR} -m "merged #${THE_PR} as part of this test"
            if [ "$?" -gt 0 ]; then
                echo "[$(date)] Merge failure!"
                append_report_row "test with" ":x:" "Mu2e/${REPO_NAME}#${THE_PR} @ ${THE_COMMIT_SHA} merge failed"
                echo "early return prepare_repositories merge fail 1 in $PWD"
                return 1
            fi
            CONFLICTS=$(git ls-files -u | wc -l)
            if [ "$CONFLICTS" -gt 0 ] ; then
                echo "[$(date)] Merge conflicts!"
                append_report_row "test with" ":x:" "Mu2e/${REPO_NAME}#${THE_PR} @ ${THE_COMMIT_SHA} has conflicts with this PR"
                echo "early return prepare_repositories conflict 1 in $PWD"
                return 1
            fi

            append_report_row "test with" ":white_check_mark:" "Included Mu2e/${REPO_NAME}#${THE_PR} @ ${THE_COMMIT_SHA} by merge"

        done
    else
        append_report_row "test with" ":white_check_mark:" "Command did not list any other PRs to include"
    fi

    cd ${WORKSPACE}/${REPO}

    if [ "${NO_MERGE}" != "1" ]; then
        echo "[$(date)] Merging PR#${PULL_REQUEST} at ${COMMIT_SHA}."
        git merge --no-ff ${COMMIT_SHA} -m "merged ${REPOSITORY} PR#${PULL_REQUEST} ${COMMIT_SHA}."
        if [ "$?" -gt 0 ]; then
            append_report_row "merge" ":x:" "${COMMIT_SHA} into ${MASTER_COMMIT_SHA} merge failed"
            echo "early return prepare_repositories merge fail 2 in $PWD"
            return 1
        fi
        append_report_row "merge" ":white_check_mark:" "Merged ${COMMIT_SHA} at ${MASTER_COMMIT_SHA}"


        CONFLICTS=$(git ls-files -u | wc -l)
        if [ "$CONFLICTS" -gt 0 ] ; then
            append_report_row "merge" ":x:" "${COMMIT_SHA} has merge conflicts with ${MASTER_COMMIT_SHA} "
            echo "early return prepare_repositories conflict 2 in $PWD"
            return 1
        fi
    fi

    echo "ls of area"
    ls -al
    echo "return prepare_repositories in $PWD"

    return 0
}

function report_merge_error() {
    cat > gh-report.md <<- EOM
${COMMIT_SHA}
$1
error
The PR branch may have conflicts.
http://github.com/${REPOSITORY}/pull/${PULL_REQUEST}
:bangbang: It was not possible to prepare the workspace for this test. This is often caused by merge conflicts - please check and try again.
\`\`\`
> git diff --check | grep -i conflict
$(git diff --check | grep -i conflict)
\`\`\`

| Test          | Result        | Details |
| ------------- |:-------------:| ------- |${MU2E_POSTTEST_STATUSES}


EOM
        cmsbot_report gh-report.md
}

# builds a report of a single test's status, to be posted on GitHub
function build_test_report() {
    i=$1
    EXTRAINFO=""
    STATUS_temp=":wavy_dash:"
    ALLOWED_TO_FAIL=0
    # Check if this test is "allowed to fail"
    for j in "${FAIL_OK[@]}"; do
        if [ "$i" = "$j" ]; then
            # This test is allowed to fail.
            ALLOWED_TO_FAIL=1
            STATUS_temp=":heavy_exclamation_mark:"
            break;
        fi
    done
    if [ -f "$WORKSPACE/$i.log.SUCCESS" ]; then
        STATUS_temp=":white_check_mark:"
    elif [ -f "$WORKSPACE/$i.log.TIMEOUT" ]; then
        STATUS_temp=":stopwatch: :x:"
        EXTRAINFO="Timed out."
        if [ ${ALLOWED_TO_FAIL} -ne 1 ]; then
            TESTS_FAILED=1
        fi
    elif [ -f "$WORKSPACE/$i.log.WARNING" ]; then
        STATUS_temp=":question:"
        EXTRAINFO="Return Code $(cat $WORKSPACE/$i.log.WARNING)."
    elif [ -f "$WORKSPACE/$i.log.FAILED" ]; then
        STATUS_temp=":x:"
        EXTRAINFO="Return Code $(cat $WORKSPACE/$i.log.FAILED)."

        if [ ${ALLOWED_TO_FAIL} -ne 1 ]; then
            TESTS_FAILED=1
        fi
    fi
    append_report_row "$i" "${STATUS_temp}" "[Log file.](${JOB_URL}/${BUILD_NUMBER}/artifact/$i.log) ${EXTRAINFO}"
}

# assembles a string containing all the directories that need to be included in a build archive
function collect_archive_list() {
    # argument is the repo this build test was for
    thisrepo=$1
    # build dir
    ARCHIVE_LIST="build $thisrepo"
    # all required build repos
    for reqrepo in "${REQUIRED_BUILD_REPOS_SHORT[@]}"; do
        if [[ $ARCHIVE_LIST != *$reqrepo* ]]; then
            ARCHIVE_LIST+=" $reqrepo"
        fi
    done
    # any "test with PR" repos that have not already been included
    if [ "${TEST_WITH_PR}" != "" ]; then
        # comma separated list
        for pr in $(echo ${TEST_WITH_PR} | sed "s/,/ /g")
        do
            # if it starts with "#" then it is a PR in the repo the build test was for and it's already included
            if [[ $pr != \#* && $pr = *\#* ]]; then
                REPO_NAME=$( echo $pr | awk -F\# '{print $1}' | sed 's|^.*/||' )
                if [[ $ARCHIVE_LIST != *$REPO_NAME* ]]; then
                    ARCHIVE_LIST+=" $REPO_NAME"
                fi
            fi
        done
    fi
}
