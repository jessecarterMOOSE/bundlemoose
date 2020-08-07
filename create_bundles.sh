#!/bin/bash

# this script creates some *initial* bundles of moose and its submodules that can be transferred to an offline network containing
# a git server (Gitlab, TFS, etc...) and clone which reproduces the entire git history
#
# to be run on *external* server
#
# for best results, run in an empty, temp directory as the script leaves a separate repo each submodule and won't be left in a state
# where `git submodule` works due to the url's used in the repos (see initialize_moose.sh script)
#
# before running, set BUNDLE_DIR for your system


# location to write bundle files
BUNDLE_DIR="$HOME/projects/zips"
rm -vf $BUNDLE_DIR/*.bundle  # clean old bundles

# clone moose and initialize libmesh and submodules (don't worry about submodules of moose for now)
git clone -b master git@github.com:idaholab/moose.git
cd moose
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
    echo;
  fi'

# bundles can now be transferred over to the internal network, ideally to be cloned using the 'clone_and_push.sh' script
