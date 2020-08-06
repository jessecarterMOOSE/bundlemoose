#!/bin/bash

# on the _external_ network (ie internet), use this script to clone base repo (eg moose) and create bundle of it and as well as submodules
# this should be run FIRST and only needed ONCE

# bundle files written to 
BUNDLE_DIR="$HOME/projects/zips/initial-bundles"

# remote to pull changes from if working on an existing rep
UPSTREAM_REMOTE='origin'  # probably 'origin' if working with moose directly or 'upstream' if working on fork

# using some newer git submodule commands
module load git

# remove any bundles made previously
rm -f $BUNDLE_DIR/*.bundle

# clone or update master branch
if [ -d "moose/" ]
then
  echo "updating existing moose repo..."
  cd moose
  git checkout master
  git pull -n $UPSTREAM_REMOTE master
else
  echo "cloning new copy of moose..."
  git clone -b master git@github.com:idaholab/moose.git
  cd moose
fi

git reset --hard 7365215  # temporary for testing
#git reset --hard 3d043ea6

# get submodules ready, but only the libmesh ones
echo "updating submodules..."
git submodule update --init --recursive libmesh

# tag commit where bundles will be created so next time we only grab changes since then
echo "tagging HEAD commits..."
git tag -f lastbundle HEAD
git submodule foreach --recursive 'git tag -f lastbundle HEAD'

# we need to change the submodule url's to point to a local (../<name>) repo so we can store all these locally on a single account
# (the internal server doesn't know who 'idaholab' is etc.)
# the thing is, we need to start at the deepest submodules (those without submodules of their own) and change those and then commit the changes
# to the submodule that owns it, all the way up, meaning we need to recurse submodules _backwards_
# also note the branch we commit url changes to will depend on whether the current submodule pointer is merged or not since we cannot fast-forward
# from an orphaned branch - submodules of libmesh (timpi, metaphysicl) tend to be like that, 
# so we apply the submodule url commit directly to it in that case, otherwise commit to master
# this is also where we make the 'external' branch that mimics master
echo "changing submodule url's and committing changes..."
wd=$PWD  # save working directory
# do a typical recusive submodule foreach, then reverse the output and parse, grabbing the directory names, then loop over them
for dir in `git submodule foreach --recursive | tac | sed 's/Entering //' | xargs -n 1`
do
  cd $wd
  cd $dir
  name=`basename $dir`
  bundle="$BUNDLE_DIR/$name.bundle"
  echo "working on $name in $dir..."

  # make an 'external' branch that mimics master
  git branch -f external master

  # optimization step: if the bundle is already available, skip - this happens when multiple submodules use the same submodule, such as all the libmesh submodules
  # use some configuration stuff and (currently) all use the same hash in that submodule, so no point in repeating the same steps
  # something will have to change here if different hashes are needed from the same submodule
  if [ -f $bundle ]
  then
    echo "already created $bundle, skipping..."
    echo
    continue
  fi

  # check if we need to update any submodules, and if not, just bundle and move on to next submodule
  if ! `git submodule | grep -q -`
  then 
    echo "no submodules in this repo, no need to update submodule url..."
    echo "creating bundle $bundle..."
    git bundle create $bundle HEAD master external lastbundle
    echo
    continue
  fi

  # submodule url changes to master if submodule pointer is merged, otherwise commit to that branch
  git checkout --detach
  if `git branch master --contains lastbundle | grep -q master`
  then 
    echo "committing submodule url change on submodule HEAD and calling it master..."
    git branch -f master lastbundle
    git checkout master
  else
    extrabranch=`git branch -a --contains tags/lastbundle | grep -v HEAD`  # gets branch submodule is sitting on
    echo "committing submodule url change to $extrabranch branch containing submodule HEAD..."
    git checkout -t $extrabranch
    extrabranch=`basename $extrabranch`  # now the branch is local, so don't need the remote anymore
  fi

  # change url's and commit and tag
  echo "changing submodule urls to local convention and committing..."
  for sub in `git submodule status | cut -c2- | cut -d " " -f 2`
  do
    git submodule set-url $sub ../`basename $sub`
  done
  git commit -am "update submodule url"
  git tag submoduleurl

  # bundle up submodule
  echo "creating bundle $bundle..."
  git bundle create $bundle HEAD master external lastbundle submoduleurl $extrabranch
  unset extrabranch
  echo
done
cd $wd

# finally commit changes to moose (still on master) and bundle
git branch -f external master
git submodule set-url libmesh ../libmesh
git commit -am "update submodule url"
git tag submoduleurl
echo "creating bundle $BUNDLE_DIR/moose.bundle..."
git bundle create $BUNDLE_DIR/moose.bundle HEAD master lastbundle external submoduleurl

# reset master back so repo is representative of external when coming back to update (ie remove submodule url changes)
echo "reverting back to normal..."
git checkout master
git reset --hard external
git tag -d submoduleurl 2> /dev/null
git submodule foreach --recursive 'git checkout master; git reset --hard external; git tag -d submoduleurl; git checkout lastbundle'

# now bundles can be transfered to internal network the repos
# and the repos cloned by this script are ready for updating again with bundles using 'update_bundles.sh'
