#!/bin/bash

# this script loops over moose and its submodules and changes the *local* configuation of the submodule url's
# without touching the files so moose can be used internally without changing any files
#
# with more thought I could come up with some slick recursive algorithm, but this works for now

# ssh remote for internal git server
REMOTE=git@github.com:jessecarterMOOSE

# clone moose and initialize libmesh
git clone -b master $REMOTE/moose.git
cd moose
git submodule init libmesh  # initialize repo so it gets an entry in local config file (.git/config)
git config --local submodule.libmesh.url $REMOTE/libmesh.git  # change libmesh url in local repo config
git submodule update libmesh  # update uses the location in the config file

# go into libmesh and initialize each of its submodules changing the local config like above
cd libmesh
git submodule init
for sub in `git submodule status | cut -c2- | cut -d " " -f 2`  # loop over submodules of libmesh
do
  name=`basename $sub`
  git config --local submodule.$sub.url $REMOTE/$name.git
done
git submodule update

# go into each one of libmesh's submodules and initialize each one of those
wd=$PWD
for libmeshsub in `git submodule status | cut -c2- | cut -d " " -f 2`
do
  cd $libmeshsub
  git submodule init
  for sub in `git submodule status | cut -c2- | cut -d " " -f 2`
  do
    name=`basename $sub`
    git config --local submodule.$sub.url $REMOTE/$name.git
  done
  git submodule update
  cd $wd
done

# check if we're done
cd ..
git submodule update --init --recursive libmesh
if [ $? -ne 0 ]
then
  echo "********************"
  echo "something went wrong"
  echo "********************"
fi
