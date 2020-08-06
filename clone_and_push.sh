#!/bin/bash

# location of bundles
BUNDLE_DIR="$HOME/projects/zips"

# ssh remote for internal git server to push
REMOTE=git@hpcgitlab.hpc.inl.gov:`whoami` 

module load git

# loop over bundle files, cloning each and push
for bundle in $BUNDLE_DIR/*.bundle
do
  name=`basename $bundle .bundle`
  git clone $bundle $name
  cd $name
  # submodules may not be on/at master, so make sure we add master manually
  if ! `git branch --show-current | grep -q master`; then git branch -f master origin/master; fi
  # rename remotes, leave the "bundle" remote so we can pull from again later
  git remote rename origin bundle
  git remote add origin $REMOTE/$name.git
  # push branches and tags
  git push -f origin --all
  git push -f origin --tags
  cd ..
done
