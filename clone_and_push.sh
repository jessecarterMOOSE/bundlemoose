#!/bin/bash

# takes git bundles and clones and pushes them to an internal git server
#
# to be run on *internal* network
#
# first ensure BUNDLE_DIR and REMOTE variables are correct
#
# for best results, run in an empty, temp directory


# location of bundles (TODO: make this an argument)
BUNDLE_DIR="$HOME/bundles"

# ssh remote for internal git server to push (TODO: make this an argument)
REMOTE=git@github.com:jessecarterMOOSE

# loop over bundle files, cloning each and push
for bundle in $BUNDLE_DIR/*.bundle
do
  name=`basename $bundle .bundle`
  git clone -b master $bundle $name
  cd $name

  # if a submodule, repo may not point at master, so make sure we checkout and push extra branches in bundle
  for branch in `git branch -r | grep -vE 'HEAD|master'`  # loop over remote branches that are not HEAD or master
  do
    git branch -f ${branch#origin/} $branch
  done
  # rename remotes, leave the "bundle" remote so we can pull from again later
  git remote rename origin bundle
  git remote add origin $REMOTE/$name.git
  # push branches and tags
  git push -u origin --all
  git push -u origin --tags

  cd ..
  echo
done
