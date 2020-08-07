#!/bin/bash

# takes git bundles and clones and pushes them to an internal git server
#
# to be run on *internal* server
#
# first ensure BUNDLE_DIR and REMOTE variables are correct
#
# for best results, run in an empty, temp directory


# location of bundles
BUNDLE_DIR="$HOME/projects/zips"

# ssh remote for internal git server to push
REMOTE=git@hpcgitlab.hpc.inl.gov:`whoami` 

module load git

# loop over bundle files, cloning each and push
for bundle in $BUNDLE_DIR/*.bundle
do
  name=`basename $bundle .bundle`
  git clone -b master $bundle $name
  cd $name

  # as submodule, repo may not point at master, so make sure we checkout and push extra branches
  for branch in `git branch -r | grep -vE 'HEAD|master'`  # loop over remote branches that are not HEAD or master
  do
    git branch -f ${branch#origin/} $branch
  done
  # rename remotes, leave the "bundle" remote so we can pull from again later
  git remote rename origin bundle
  git remote add origin $REMOTE/$name.git
  # make sure master is tracking origin so submodules pull from it
  git branch master -u origin/master
  # push branches and tags
  git push -f origin --all
  git push -f origin --tags
  cd ..
  echo
done
