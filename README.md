Partial automation for custom TinkerPop builds at DataStax

The sole script in bin expects to be run from TP's git repository.
It does a few things:

* note the current HEAD commit
* apply patches in the patch directory, which point TP at DS's Maven repo
* set a new project version based on the current version minus -SNAPSHOT,
  the current datestamp, and the leading characters of the current HEAD
  commit hash
* add these changes to the index and commit
* create a new tag matching the project version generated above
* hard-reset the branch (if applicable) to the original HEAD
* checkout the tag

This script does *not*:

* Deploy/install to a Maven repo, local or remote
* Push to git repo, local or remote (the script does not push to github)

Hence, effects of the script are limited to the local machine.  If the script
script somehow runs amok, the damage should be contained and reversible.
