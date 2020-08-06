#!/bin/bash

# location of bundles
BUNDLE_DIR="$HOME/projects/zips"

# ssh remote for internal git server to push
REMOTE=git@hpcgitlab.hpc.inl.gov:`whoami` 

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
