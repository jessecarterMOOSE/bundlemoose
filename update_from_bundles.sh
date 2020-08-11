#!/bin/bash

# takes updated git bundles and updates existing internal repos and pushes changes to the internal git server
#
# to be run on *internal* server
#
# first ensure BUNDLE_DIR and REMOTE variables are correct
#
# for best results, run in an empty, temp directory


# location of bundles (TODO: make this an argument)
BUNDLE_DIR="$HOME/bundles"

# ssh remote for internal git server to push (TODO: make this an argument)
REMOTE=git@github.com:jessecarterMOOSE

module load git

# loop over bundle files, clone exiting repo, then update and push
for bundle in $BUNDLE_DIR/*.bundle
do
  # clone
  name=`basename $bundle .bundle`
  git clone -b master $REMOTE/$name.git $name
  cd $name

  # update master and tag
  git remote add bundle $bundle
  git fetch bundle
  git pull -n bundle master
  git tag -f lastbundle

  # create any new branches contained in bundle
  for branch in `git branch -r | grep bundle | grep -vE 'HEAD|master'`
  do
    git branch -f ${branch#origin/} $branch
  done

  # push branches and tags
  git push origin --all
  git push -f origin --tags
  cd ..
  echo
done
