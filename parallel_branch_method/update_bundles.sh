#!/bin/bash

# make new bundles from the _external_ repo, such as your fork on github/gitlab, containing changes since last time (lastbundle tag)
# pushes upstream/master and lastbundle tag to external repo, so need to have permissions (ie a fork)
# use this script every time you wish to update the internal repo

# bundle files written to 
BUNDLE_DIR="$HOME/projects/zips/updated-bundles"

# use this remote to get new commits, will be origin if originally cloned from idaholab/moose or upstream if cloned from fork
UPSTREAM_REMOTE='origin'

# use this remote to push updated master branch and tag, leave blank if not pushing to your fork
FORK_REMOTE='' # 'origin'

# clean up from last time
rm -f $BUNDLE_DIR/*.bundle

# go through submodules and tag where we last created bundles in case they are not marked 
# (since we probably cannot push tags to upstream submodule repos)
cd moose
git checkout master
git reset --hard lastbundle
git submodule update --init --recursive libmesh  # make sure we are initialized
git submodule foreach --recursive 'git tag -f lastbundle'  # tag submodule commits that are active *before* the update

# update repo and submodules
echo "pulling upstream changes..."
git pull -n $UPSTREAM_REMOTE master
#git reset --hard 7365215  # temp for testing
git submodule update --recursive libmesh

# check if any updates are available since last bundle
if [ "$(git rev-parse HEAD)" == "$(git rev-parse lastbundle)" ]
then
  echo "no changes found since last bundle, exiting..."
  exit
fi

# bundle changes between last bundle and master on top-level
echo "writing $BUNDLE_DIR/moose.bundle..."
git bundle create $BUNDLE_DIR/moose.bundle lastbundle..master master

# update tag to remember which commit we updated to
git tag -f lastlastbundle lastbundle
git tag -f lastbundle master

# push if remote was supplied
if [ "X$FORK_REMOTE" != "X" ]
then
  git push $FORK_REMOTE master
  git push -f $FORK_REMOTE lastbundle
fi

# recurse through submodules to see what changed: HEAD will be different than lastbundle tag if submodule was updated
# then do the same we did above, though HEAD might be detached
# also check if we may run into any problems applying the bundle later
dir=$BUNDLE_DIR git submodule foreach --recursive '
if [ "$(git rev-parse HEAD)" != "$(git rev-parse lastbundle)" ];
then
  git branch -f external master;
  if [ ! `git find-merge lastbundle HEAD` ]; then 
    echo "  *** previous bundle point may not be merged, try resetting $name to $(git rev-parse --short $(git merge-base lastbundle HEAD)) before applying bundle ***";
    extrabranch=`git branch -a --contains HEAD | grep -v HEAD`;
    git checkout -t $extrabranch;
    extrabranch=`basename $extrabranch`;
  fi
  git tag -f lastlastbundle lastbundle;
  git tag -f lastbundle HEAD;
  echo "writing $dir/`basename $name`.bundle...";
  git bundle create $dir/`basename $name`.bundle lastlastbundle..HEAD HEAD external lastbundle $extrabranch;
  unset extrabranch;
  echo;
fi'
