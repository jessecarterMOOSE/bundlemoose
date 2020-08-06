#! /bin/bash

# use this script on the _internal_ network (with standalone git server like gitlab) to loop over bundles, clone, and push
# internal git server will need to have the repos already created, but they can be empty, or if not, will be overwritten by force push 
# should only be needed ONCE

# url we will push to (called origin below)
URL="git@hpcgitlab.hpc.inl.gov:cartjess"

# where the bundles are
BUNDLE_DIR="$HOME/projects/zips/initial-bundles"

# loop over bundles we find
for bundle in $BUNDLE_DIR/*.bundle
do
  # clone bundle
  echo "cloning from $bundle..."
  name=`basename $bundle .bundle`  # repo name
  git clone -b master $bundle  # sets tags too
  cd $name

  # also add external branch from bundle
  git branch -t external origin/external

  # set up remote (was bundle), could be bundle again if we want to replace old bundles with new ones
  git remote set-url origin $URL/$name.git

  # create a branch that mimics the external master at the bundle tag (and draws attention to the difference between it and local master)
  # git branch external lastbundle
  # tag the master commit which will have submodule url changes
  # git tag -f submoduleurl master

  # push (force pushing for debugging purposes)
  git push -f origin --all  # branches
  git push -f origin --tags #lastbundle #submoduleurl  # tags
  #if `git bundle list-heads $bundle | grep -q 'submoduleurl' -`; then git push -f origin submoduleurl; fi

  # master needs to track origin so submodules pull from origin not bundle
  git branch -u origin/master master
  cd ..

  echo
done
