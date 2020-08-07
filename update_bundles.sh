#!/bin/bash

# this script creates updated bundles from the last time moose repos were updated
#
# to be run on *external* server
#
# ensure the REMOTE and BUNDLE_DIR variables are correct
#
# for best results, run in an empty, temp directory

# ssh remote for internal git server to push
REMOTE=git@hpcgitlab.hpc.inl.gov:`whoami`

# location for bundles
BUNDLE_DIR="$HOME/projects/zips"
rm -vf $BUNDLE_DIR/*.bundle  # clean old bundles

# remember where we were last time
git clone -b master $REMOTE/moose.git
cd moose
git reset --hard lastbundle
git submodule update --init --recursive libmesh
git submodule foreach --recursive 'git tag -f lastbundle HEAD'

# update moose according to their instructions
git fetch origin
git rebase origin/master
git submodule update --recursive libmesh

# check if any updates are available since last bundle
if [ "$(git rev-parse HEAD)" == "$(git rev-parse lastbundle)" ]
then
  echo "no changes found since last bundle, exiting..."
  exit
fi

# mark new and old bundle points
git tag -f lastlastbundle lastbundle
git tag -f lastbundle HEAD

# bundle up moose
bundle=$BUNDLE_DIR/moose.bundle
echo "writing $bundle..."
git bundle create $bundle lastlastbundle..master master HEAD lastbundle

# bundle up submodules, but skip if bundle already exists (libmesh submodules use a common submodle for configuration stuff)
# or skip if HEAD is not updated
# also if submodule HEAD isn't on master, need to grab that branch too
dir=$BUNDLE_DIR git submodule foreach --recursive '
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse lastbundle)" ]; then
    repo=`basename $name`; 
    bundle=$dir/$repo.bundle;
    if [ ! -f $bundle ]; then
      git checkout --detach;
      git branch -f master origin/master;
      if ! `git branch --contains HEAD | grep -q master`; then 
        git checkout -t `git branch -a --contains HEAD | grep -v HEAD`
        extrabranch=`git branch --show-current`; 
      fi 
      echo "writing $bundle...";
      git bundle create $bundle lastbundle..master master HEAD $extrabranch;
      echo;
    fi;
  fi'
