﻿# bundlemoose
### Maintain an offline mirror of MOOSE (and submodules) that looks just like the real thing!

This repo contains several bash scripts for creating and maintaining an offline copy of [MOOSE](https://mooseframework.org/) and its various [submodules](https://git-scm.com/docs/git-submodule), doing so in a way that keeps the full git history of the projects. It is accomplished through the use of [git bundles](https://git-scm.com/docs/git-bundle), which are specifically designed for such a situation. Each repo, or a portion of it, is completely encapsulated inside a single bundle file which can be cloned or fetched from like any other remote. The bundles can be transferred over to a standalone network and re-combined to create a mirror of the external stack. The repos can also be pushed a git server (Gitlab, TFS, etc.) on the standalone network for distribution and development.

The [MOOSE repo](https://github.com/idaholab/moose) itself requires [libmesh](https://github.com/libMesh/libmesh) to run which is conveniently available as a submodule inside MOOSE. Inside of libmesh, there are two other repos that are required: [TIMPI](https://github.com/libMesh/TIMPI) and [MetaPhysicL](https://github.com/roystgnr/MetaPhysicL), both of which depend on a [third libmesh submodule](https://github.com/libMesh/autoconf-submodule) for configuration. Of course the current design is subject to change, so we make use of `git submodule foreach --recursive` to recursively visit each submodule to grab or apply the necessary changes. There are other submodules of MOOSE that are not strictly necessary to build, so they are explicitly ignored for now.

One hiccup to this whole process comes from the fact that the external submodule locations are hardcoded in the repo, i.e. in the `.gitmodules` file, and those url's are not reachable from the standalone network. One could simply modify the `.gitmodules` file to point to the internal locations, but committing that change that would change the hash values across potentially the whole repo future updates difficult. An initial effort on this project attempted to maintain a parallel branch with this modified file and merging in external changes, but became too convoluted especially in light of the fact that it was to support only a few lines of code.

The solution adopted here is to simply modify the local configuration of the moose repo when initially cloned to point the submodules at the local addresses. This can be done by first initializing a repo (e.g. `git submodule init libmesh`), which adds an entry to the local configuration but does not actually clone the repo. At this point the local configuration can be modified to point to the new url. Doing so involves either making a change to the local config file (located at `.git/config`) or using the command line (e.g. `git config --local submodule.libmesh.url <your_remote>/libmesh.git`). Either way, subsequently updating the submodule (e.g. `git submodule update libmesh`) uses the local configuration file rather than the `.gitmodules` file so the repo remains untouched. The same changes need to be made to further submodules of libmesh. Not to worry, a bash script is included in this repo (`initialize_moose.sh`) to do this for you.

### The Caveat

As mentioned above, getting this to work is unfortunately not as easy as simply copying over the bundle files and cloning (though it is pretty close) due to the fact that submodule url's are hardcoded in the `.gitmodules` files. So yes, tweaking the local configuration is an extra step to make this procedure work. However, it is only a one-time step done up front, and the included `initialize_moose.sh` takes care of it for you. In my opinion this tradeoff is worth it to use all repos as-is with the full history and hash values preserved. This also simplifies the updating process through the use of normal commands like `git fetch` and `git pull`. Other attempts involved too much hacking or additional scripting.

### Procedure

With that aside, the procedure works like this:
1. Run the `create_bundles.sh` script in an empty directory on an <ins>external</ins> server with internet access. There is a variable in the bash script that can be edited to write the bundle files to a different directory (TODO: make this an argument). Running the script will clone the main MOOSE repository, then initialize all submodules and bundle up each's master branch up to the current master HEAD. Note that if a repo is requesting a commit in the submodule that is not on a merged branch (submodules of libmesh tend to do this), that branch is also created in the bundle. This leaves several bundle files (currently 5) ready for transfer. In the moose repo, a tag called `lastbundle` (taken from the example in the [git bundle documentation](https://git-scm.com/docs/git-bundle#_examples)) is created to remember where we were when we come back to update later.
2. Transfer bundle files over to the separate network and copy to a common location.
3. On the <ins>internal</ins> network, run the `clone_and_push.sh` script to clone each of these repos in turn and push the contents to the internal git server. Two variables need to be addressed in the script: the location of the bundles and the remote url of the internal git server (values currently in the script point to INL locations used for testing). Note the repos will likely first need to be created on the internal git server. Also note that local directories generated by this script are really just temporary standalone repos that can be deleted (so you can use temp space for this), though note the location of the `lastbundle` tag (current master commit hash) in case you forget and delete it on the external side of things.
4. When a user wishes to clone and run MOOSE on the *internal* network, use the `initialize_moose.sh` script to do this in order to make the necessary modifications to the local configuration and clone the repo and submodules. Check the location of the remote variable in the script before doing so. This will create a moose directory in the current working directory containing moose and all submodules.
5. At some point later, when the MOOSE development has progressed and you wish to update your internal copy, re-visit the location of the cloned MOOSE repo on the <ins>external</ins> server and run `update_bundles.sh`, but like before, check the file location in the script and provide a valid location for the bundle files to be written. Also note the `lastbundle` tag needs to be available to know where to update from. If this is no longer available, it should have been pushed to the *internal* git moose repo, or may just be the current master HEAD. Take note the hash of the commit (either `git log -1 lastbundle` or `git log -1 master` if the internal master hasn't been touched) and create it on the external server by going into the moose directory and running `git tag -f lastbundle <commit>`. Then when `update_bundles.sh` is run, bundle files will be created for any repo that has been updated since the last update. This can be done as many times as necessary, but note that it moves up the `lastbundle` tag each time so if a update goes awry, the tag will need to be reset. For this reason, another tag called `lastlastbundle` is created in the spot of the previous update and can be used to reset the tag by running `git bundle -f lastbundle lastlastbundle`.
6. Update the internal repo by running `update_from_bundles.sh` on the <ins>internal</ins> network, again making sure the script variable is pointing at the bundle directory as well as the remote url. This can be kept the same for each update. Like above, the script should be run in an empty, temp directory as it clones the internal repos, performs the updates, and pushes back, and is safe to delete when done.
7. The user wishing to update their local master branch can use typical methods such as `git pull`.
8. Need to update the internal server again? See step 5.

Under the hood, the update process for the most part simply does a `git pull <bundle>` to update the repo's master branch and sets the `lastbundle` tag. Some more work goes into the submodules if a commit is needed that is not on master. Creating the bundles initially and updating them later is really the same process, only instead of specifying the master branch be bundled, the range `lastbundle..master` is given, and only those commits since `lastbundle` are bundled. The initial bundles can be large for a big project like MOOSE or libmesh (few hundred MB), but subsequent updates and submodules are smaller.

Lastly, it should be noted that this procedure can generally be applied to any repo with or without submodules. The only reason why it is not implemented in a more general sense is the desire to only update the libmesh submodule of moose and not others. This could certainly be still done with a slick, recursive algorithm with some 'exclusion list' of submodules or something, I just haven't gotten around to it.

Jesse Carter

> Written with [StackEdit](https://stackedit.io/).
