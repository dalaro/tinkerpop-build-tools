#!/bin/bash

if [ x"$1" = x"" ] ; then
    echo "Usage: $0 <new-tinkerpop-version>"
    echo "  Must be run from a dse-graph-api repository root directory."
    echo "  The index and working copies of tracked files must be clean."
    echo
    echo "  Creates and checks out a new branch (based on current branch)"
    echo "  named upgrade-to-TinkerPop-<new-tinkerpop-version>."
    echo
    echo "  Updates build.gradle to depend on the supplied TP version."
    echo
    echo "  Also modifies the project version, which must be in the format "
    echo "    [0-9.]+\+TP\.(lowercase hex hash of the tinkerpop dependency)"
    echo "  The only part of the project version that this script changes"
    echo "  is the hex portion following \"TP.\"."
    echo 
    echo "  Adds this modified build.gradle file to the git index and"
    echo "  commits it to the branch."
    echo
    echo "  This script does to push or merge.  It leaves the git repo"
    echo "  on the branch it created.  It is the caller's responsibility"
    echo "  to push/merge after this script exits, if desired."
    echo
    echo "  This script exits with zero status if it thinks it has"
    echo "  succeeded and nonzero status when it encounters a failure."
    exit 2
fi

set -e
set -u

# Check that there are no changes in tracked files
# I stole this from git-stash, which is also a shell script
if git diff-index --quiet --cached HEAD --ignore-submodules -- &&
    git diff-files --quiet --ignore-submodules ; then
   echo 'Tracked files and git index appear clean.'
else
   echo 'Tracked files or git index appear dirty.  Exiting.'
   exit 2
fi

echo 'Gathering version information...'

echo 'Running ./gradlew -q printTinkerpopVersion...'
declare -r TP_OLD_VER=$( ./gradlew -q printTinkerpopVersion )
declare -r TP_OLD_HASH=$( echo $TP_OLD_VER | sed -r 's/.*-([0-9a-f]+)$/\1/' )
echo 'Running ./gradlew -q printProjectVersion...'
declare -r PROJECT_OLD_VER=$( ./gradlew -q printProjectVersion )

# e.g. 3.2.1-20160606-406956db
declare -r TP_NEW_VER=$1
declare -r TP_NEW_HASH=$( echo $TP_NEW_VER | sed -r 's/.*-([0-9a-f]+)$/\1/' )
declare -r PROJECT_NEW_VER=$( echo $PROJECT_OLD_VER | sed -rn 's/^([0-9.]+\+TP\.)[0-9a-f]+$/\1'${TP_NEW_HASH}'/p' )

declare -r BRANCH_NAME="upgrade-to-TinkerPop-$TP_NEW_VER"

if [ x"$PROJECT_NEW_VER" = x"" ] ; then
    echo "Could not generate new project version."
    echo "Current project version: $PROJECT_OLD_VER"
    echo "Maybe it does not follow the 1.2.3+TP.<hexhash> format?"
    exit 3
fi

echo
echo "Current version info:"
echo "----------------------------------------"
echo "TP version:      $TP_OLD_VER"
echo "TP hash:         $TP_OLD_HASH"
echo "Project version: $PROJECT_OLD_VER"

echo
echo "Target version info:"
echo "----------------------------------------"
echo "TP version:      $TP_NEW_VER"
echo "TP hash:         $TP_NEW_HASH"
echo "Project version: $PROJECT_NEW_VER"
echo

echo "Creating and checking out branch $BRANCH_NAME..."

git checkout -b "$BRANCH_NAME"

echo "Modifying build.gradle..."

sed -f - -i build.gradle << SED_SOURCE
    s/version = .*/version = '${PROJECT_NEW_VER}'/;
    s/\(group: 'org.apache.tinkerpop', name: 'gremlin-groovy',\) version:'${TP_OLD_VER}'/\1 version:'${TP_NEW_VER}'/;
SED_SOURCE

# Ask gradle for the new TP and project versions.
# Both must match expectations.

echo "Modified build.gradle."
echo

echo "Beginning check phase..."

echo 'Running ./gradlew -q printTinkerpopVersion...'
declare -r TP_CHECK_VER=$( ./gradlew -q printTinkerpopVersion )
echo 'Running ./gradlew -q printProjectVersion...'
declare -r PROJECT_CHECK_VER=$( ./gradlew -q printProjectVersion )

exit_code=0

if [ x"$TP_CHECK_VER" != x"$TP_NEW_VER" ] ; then
    echo "Tinkerpop version mismatch: expected $TP_NEW_VER but gradle reports $TP_CHECK_VER"
    exit_code=1
else
    echo "Tinkerpop version reported by gradle: $TP_CHECK_VER (OK)"
fi 

if [ x"$PROJECT_CHECK_VER" != x"$PROJECT_NEW_VER" ] ; then
    echo "Project version mismatch: expected $PROJECT_NEW_VER but gradle reports $PROJECT_CHECK_VER"
    exit_code=1
else
    echo "Project version reported by gradle:   $PROJECT_CHECK_VER (OK)"
fi

if [ $exit_code -eq 0 ] ; then
    echo "Checks succeded."
else
    echo "One or more checks failed."
    exit $exit_code
fi

echo

echo "Adding build.gradle to the git index..."

git add build.gradle

echo "Changes to be committed:"

git diff --cached

echo "Committing..."

git commit -m "Upgrade to TinkerPop $TP_NEW_VER"

echo "Committed."
