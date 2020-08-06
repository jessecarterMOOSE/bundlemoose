#!/bin/bash

# update the _internal_ repo from bundles and push to internal remote, like TFS or something
# due to my ineptitude, this process may not work flawlessly

module load git

# where to look for bundles
BUNDLE_DIR="$HOME/projects/zips/updated-bundles"

# make sure we are ready to update using external branches (todo: might need to first sync submodule url's to local scheme in master branch,
# which would involve checking out master branch and doing a `git submodule sync --recursive libmesh`)
cd moose
git checkout master
git submodule update --init --recursive libmesh  # make sure we are using local url's for submodules
#git checkout -B external origin/external  # probably already have external branch available, but a fresh clone of moose will not
#git submodule update --recursive libmesh  # make all submodules look like their external equivalent for updating

# need to recurse submodules backwards because anything with a downstream submodule will be looking for the
# hash in the remote and it won't be there
wd=$PWD  # save working directory
for dir in `git submodule foreach --recursive | tac | sed 's/Entering //' | xargs -n 1`
do
  name=`basename $dir`
  bundle="$BUNDLE_DIR/$name.bundle"
  # only update if we have a bundle file available
  if [ -f "$bundle" ]
  then
    echo "updating from $bundle..."
    cd $dir

    # check if any submodules contained within *this* repo were changed and need to be commited, assume they need to committed to master
    commit_submodules=0
    for sub in `git submodule status | cut -c2- | cut -d " " -f 2`
    do
      if [ "X`git diff --name-only`" == "X$sub" ]
      then        
        echo "submodule $sub changed"
        commit_submodules=1
      fi
    done
    if [ $commit_submodules -eq 1 ]
    then
        git status
        echo "switching to master to commit submodule chages..."
        git checkout master
        git commit -am "update changes in submodule"
    fi
    
    git remote remove bundle 2> /dev/null
    git remote add bundle $bundle  # add bundle remote if we didn't already have it
    git checkout --detach   # detach head so we can move about easier
    git fetch --all  # fetch from bundle
    git branch -f external bundle/external  # move pointer to latest external master branch
    git fetch bundle HEAD:bundle_HEAD  # create temporary branch at current submodule pointer
 
   # need to check if previous bundle commit in submodule was merged, otherwise we cannot simply pull in changes and merge to master
    if [ ! `git find-merge lastbundle bundle_HEAD` ]; then
      echo '  *** instead of merging changes, just inserting the submodule url commit on top of the current bundle HEAD ***'
      # find branch name that contains the un-merged HEAD, check it out, and add submodule url commit
      extrabranch=`git branch -a --contains bundle_HEAD | grep -v HEAD`
      echo "need to checkout $extrabranch to cherry-pick submoduleurl commit..."
      git checkout -t $extrabranch
      git cherry-pick submoduleurl
    else
      # merge bundle HEAD into master
      git checkout master
      git merge -n -m 'include latest external changes' bundle_HEAD
      # *sigh* can't seem to cleanly merge when submodules don't fast-forward
      # for now, go ahead and just assume the hashes checked out by the submodules are correct and move on
      # just make sure the user knows...
      if [ $? -ne 0 ]
      then
        echo "  *** MERGE FAILED ***"
        echo "diff:"
        git diff
        echo "proceeding assuming submodules are properly checked and out committing..."
        echo
        git commit -a --no-edit
      fi
    fi
    # update and cleanup
    git branch -D bundle_HEAD
    git tag -f lastbundle external
    git push origin --all
    git push -f origin lastbundle
    cd $wd
    echo
  fi
done

# incorporate external libmesh changes on its master branch on moose's master branch
# but only if libmesh changes were made
git checkout master
if [ -f $BUNDLE_DIR/libmesh.bundle ]
then  
  git commit -am "update libmesh submodule"
fi

# then update top-level external branch
echo "updating from $BUNDLE_DIR/moose.bundle"
git remote remove bundle 2> /dev/null
git remote add bundle $BUNDLE_DIR/moose.bundle
git fetch bundle master:external  # note this master is the external master, which is being applied to our external branch internally
git tag -f lastlastbundle lastbundle
git tag -f lastbundle external

# finally merge in external changes and push
git merge -n -m "Merge external branch" external
git push origin --all
git push -f origin lastbundle lastlastbundle



