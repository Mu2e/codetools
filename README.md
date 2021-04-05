# KinKal_to_UPS
Tools to build the KinKal package and install it in UPS.

## Introduction

There are two extreme ways to use this package:
  1) If you already have an exisiting build, you can create a UPS repository and install the existing build there.
  2) Start with nothing, clone, checkout, and, for both build prof and debug, build, test and install.

There are command line options to choose intermediate amounts of work.

## Instructions for case 1

The simplest example is that you have a working directory that contains 2 directories:

>  KinKal build_debug


and you already have a UPS **debug** version of root set up in the environment.  In that directory do
the following:

* git clone https://github.com/kutschke/KinKal_to_UPS.git
* KinKal_to_UPS/build -h  # to see the help
* KinKal_to_UPS/build -v <git_tag_name> -i

This will look for the source in the subdirectory KinKal and for the built debug version in
the subdirectory build_debug.  It will install the already built git tag and into the default UPS
repository, which is ./artexternals; the UPS repository will be created if necessary.  The git tag
is needed in order to name the UPS product version.

For example, if git_tag_name is v0.1.1, the UPS installation will be located at:

   artexternals/KinKal/v00_01_01

and the UPS qualifiers will be copied from the underlying root UPS pacakge.

To use this UPS product:

* export PRODUCTS=${PWD}/artexternals:${PRODUCTS}
* ups list -aK+ KinKal
* setup -B KinKal VERSION -qQUALIFIERS

You can access the headers and libraries with the usual -I$KINKAL_INC and -L$KINKAL_LIB.  An include directive within a .cc file should look like:

  #include "KinKal/Fit/Track.hh"


## Instructions for Case 2

Start in a clean working directory with no UPS version of root or cmake already setup.

* git clone https://github.com/kutschke/KinKal_to_UPS.git
* setup mu2e
* KinKal_to_UPS/build -v "v0.1.1" -n -b -t -i -z -c "v3_18_2" -r "v6_20_08a -q+e20:+p383b:+prof" -j 24   -d ${PWD}/artexternals

This will do the following
* For the requested git tag of KinKal this will clone, checkout, cmake, make, make tests, install into UPS, and make tar files for installation on cvmfs.
* The ups repository into which it is installed is given by the -d option; the default is ${PWD}/artexternals.
* It will use the indicated versions of cmake and root; there is a default for cmake but only sort-of for root (see below).
* The make step will do a 24 way parallel build, which is appropriate for mu2ebuild01; the default is a one thread build.
* It will build both prof and debug; it knows that cmake spells these Release and Debug.
* It assumes that debug version of ROOT differs from the prof version by the exchange prof->debug in the qualifier string
* If you omit the -r qualifier, and if there is already a UPS version of root set up in the environment, this command will only build and install one of prof/debug, the one matching the version of root already set up.
* If you omit the -r qualifier, and if there is no UPS version of root setup in the environment, it is an error.

When this is complete you will see the following subdirectories of clean_working_dir
* KinKal_to_UPS - this package
* KinKal        - the cloned source
* build_prof    - the working space for the Release (prof) build
* build_debug   - the working space for the Debug (debug) build
* artexternals  - the UPS repo into which the code is installed.

You will also see two files:
* KinKal_prof.tar.bz2
* KinKal_debug.tar.bz2

These tar.bz2 files are formatted to be unwound into /cvmfs/mu2e.opensciencegrid.org/artexternals .

You can point the UPS repo at an arbitrary directory using the -d option but the other four directory names are hard coded.

The default behaviour is to abort if the KinKal directory already exists; it will overwrite existing files in build_prof, build_debug
and artexternals/KinKal.

## Fixmes, Todos and questions

* For Jenkins, Ray prefers separate commands for prof/debug not one command to do both
* For the development environment, Dave is OK with separate commands for prof/debug but would like to do both with a single command.
* Do not needlessly rerun cmake; check for one of it's artifacts and skip.
* git clone will fail if the directory KinKal exists and is non-empty. Is it acceptable to count on this or do we want our own check?
* Is there a better name than KinKal_to_UPS?
* Should KinKal_to_UPS be installed in UPS?
* In the case of installing a prebuilt version of KinKal, is there a way to automatically determine the git tag so that it does not need to be given by hand in the install command?
* Add an option to add additional qualifiers to the KinKal product
* Is it OK that the names build_prof, build_debug are hard coded?  If not, we can make options to define them.
* What additional checks for corner cases are needed?
* I need to roll up the return statuses to one overall exit status and update the exit message.
* Rename the tar.bz2 files to match the scisoft standard.
* If we do a git checkout of the named tag, we assume that \<tagname\>_branch is a valid git branch name.  Is that safe?
* What else?
