#!/bin/bash

# location for bundles
BUNDLE_DIR="$HOME/projects/zips/initial-bundles"
rm -vf $BUNDLE_DIR/*.bundle  # clean old bundles

# clone moose and initialize libmesh and submodules (don't worry about submodules of moose for now)
git clone -b master git@github.com:idaholab/moose.git
cd moose

git reset --hard 7365215  # for debugging

git submodule update --init --recursive libmesh

# remember where we are
git tag -f lastbundle HEAD

# bundle up moose
bundle=$BUNDLE_DIR/moose.bundle
echo "writing $bundle..."
git bundle create $bundle master HEAD lastbundle

# bundle up submodules, but skip if bundle already exists (libmesh submodules use a common submodle for configuration stuff)
# also if submodule HEAD isn't on master, need to grab that branch too
dir=$BUNDLE_DIR git submodule foreach --recursive '
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
    git bundle create $bundle master HEAD $extrabranch;
  fi'
