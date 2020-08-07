#!/bin/bash

# this script creates updated bundles from the last time moose repos were updated
#
# to be run on *external* server, from directory which contains moose
#
# ensure the BUNDLE_DIR variable is correct for your system
#
# note: this needs the 'lastbundle' tag to know where to update from, and will exit if not present
# can be set with `git tag -f lastbundle [<commit>]` where the commit is optional and will default to HEAD

# location to write bundle files
BUNDLE_DIR="$HOME/projects/zips"

# check moose directory is present
if [ ! -d "moose" ]; then echo "run from directory that contains 'moose' directory'"; exit 1; fi

# check for lastbundle tag
cd moose
if ! `git tag | grep -q lastbundle`; then echo "could not find 'lastbundle' tag, set one with 'git tag -f lastbundle <commit>"; exit 1; fi
echo "updating from `git rev-parse --short lastbundle`..."

# clean old bundles
rm -vf $BUNDLE_DIR/*.bundle

# go to where we were last time
git reset --hard lastbundle
git submodule update --init --recursive libmesh
git submodule foreach --recursive 'git tag -f lastbundle HEAD'

# update moose according to their instructions
git fetch origin  # 'origin' assumes we are working on a direct clone of moose and not a fork
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
# also if submodule HEAD isn't on master, need to grab that branch too (libmesh submodules tend to do this)
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
