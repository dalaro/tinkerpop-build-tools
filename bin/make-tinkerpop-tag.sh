#!/bin/bash
#
# This script makes DataStax-internal TinkerPop builds.
#
# 0. Stores the current 8 characters of the commit under git's current
#    HEAD into a variable.
#
# 1. Applies a patch to the root pom.xml file to point `mvn deploy` to
#    DS's maven server and change the <scm> section to
#    https://github.com/dalaro/incubator-tinkerpop
#
# 2. Runs `mvn versions:set` to change the project version to
#    <whatever the version is now>-<8 chars of git commit>
#
# 3. Adds changes to all poms and commits.
#
# 4. Creates a tag with the same name as the project version set in 2.
#
# This script does *not* run `mvn install` or `mvn deploy` or `git
# push`.  In other words, it only changes the local git repository by
# adding new commits.

# Die if any command exits with nonzero status
set -e
# Die on attempt to dereference undefined variable
set -u

# Store working directory
declare -r ORIGWD=$(pwd)

# Set $BIN to the absolute, symlinkless path to $SOURCE's parent
# ${BASH_SOURCE[0]} is the path to this file
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    BIN="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$BIN/$SOURCE"
done
declare -r BIN="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Restore original working directory
cd "$ORIGWD"

# Declare some constants
declare -r TP_REPO_DIRECTORY=~/tinkerpop
declare -r COMMIT_HASH=`git rev-parse HEAD`
declare -r COMMIT_HASH_ABBREV=`echo $COMMIT_HASH | head -c 8`
declare -r PATCH_FILES="$BIN"/../patch/*.patch
declare -r PATCH_OPTIONS=-p1
CURRENT_PROJECT_VERSION="`mvn help:evaluate -Dexpression=project.version | grep -v '^\['`"
declare -r CURRENT_PROJECT_VERSION="`echo $CURRENT_PROJECT_VERSION | sed -r 's/-SNAPSHOT$//'`"
declare -r DATESTAMP=`date +'%Y%m%d'`
declare -r GIT_USER_NAME="`git config user.name`"
declare -r GIT_USER_EMAIL="`git config user.email`"
declare -r NEW_PROJECT_VERSION="$CURRENT_PROJECT_VERSION"-"$DATESTAMP"-"$COMMIT_HASH_ABBREV"

echo "Changing directory to $TP_REPO_DIRECTORY"

cd $TP_REPO_DIRECTORY

# On second thought, the name of the branch is not particularly useful.
# Knowing the exact HEAD commit hash is more useful.
## Check that we are on a branch
#if CURRENT_BRANCH=$(git symbolic-ref --short -q HEAD); then
#    echo 'Currently on branch: ' $CURRENT_BRANCH
#else
#    echo 'Not on a branch.  Exiting.'
#    exit 1
#fi

# Check that there are no changes in tracked files
# I stole this from git-stash, which is also a shell script
if git diff-index --quiet --cached HEAD --ignore-submodules -- &&
    git diff-files --quiet --ignore-submodules ; then
   echo 'Tracked files and git index appear clean.'
else
   echo 'Tracked files or git index appear dirty.  Exiting.'
   exit 2
fi

echo 'Calculated new target project version:' $NEW_PROJECT_VERSION

# Apply all patches in the patch/ directory
while read -rd $'\0' p; do
    echo 'Applying patch: ' $p " (working dir: `pwd`)"
    patch $PATCH_OPTIONS < "$p"
done < <(find "$BIN"/../patch/ -type f -iname '*.patch' -print0)

echo 'Updating Maven project version: ' $CURRENT_PROJECT_VERSION ' -> ' $NEW_PROJECT_VERSION

mvn versions:set -DnewVersion="$NEW_PROJECT_VERSION" -DgenerateBackupPoms=false

echo 'Adding pom.xml changes to the git index'

git add -u `find -name pom.xml`

declare -r COMMIT_MESSAGE='Tag build '"$NEW_PROJECT_VERSION"

echo "Committing changes to git (commit message: $COMMIT_MESSAGE)"

git status

git commit -m "$COMMIT_MESSAGE"

echo "Creating tag named $NEW_PROJECT_VERSION"

git tag -a -m "Base commit: $COMMIT_HASH. Tagger: $GIT_USER_NAME <$GIT_USER_EMAIL>." "$NEW_PROJECT_VERSION"

echo "Custom build tag $NEW_PROJECT_VERSION created."

echo 'Hard-resetting to' $COMMIT_HASH

git reset --hard $COMMIT_HASH

to_checkout=refs/tags/"$NEW_PROJECT_VERSION"

echo Checking out $to_checkout

git checkout "$to_checkout"
