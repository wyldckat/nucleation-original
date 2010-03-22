#!/bin/bash
#
#
# USAGE: ./installOF.sh
#

#History: ---- THIS INFO IS GOING HERE BECAUSE THIS WAS A WORK BEFORE REPOSITORY -------
#2010-03-21 - Bruno Santos:
# * Compacted cookbook script multi-architecture to a single block, instead of two
# * Automatic search for closest sourceforge mirror
# * Default options set at the beginning of the script
# * upgrade in apt-get is now optional
# * interaction is optionable, but for now only via default settings
# * added option to build OpenFOAM code documentation, but lacks adding needed packages to apt-get
# * added option for using startFoam alias for OpenFOAM environment, instead of making OpenFOAM be always set
# * the script makes a log of its self execution
# * estimate (based on bogomips) and actual timing of Allwmake is also made
# * this script doubled in size...
#
# Yet to do / limitations:
# - Multi-language support, since this script has only been tested in Ubuntu's standard english
# - add option to build OpenFOAM's gcc, but also will need patching of 3 missing files
# - Add Qt 4.3.5 building, especially for Ubuntu 8.04 LTS
# - Add building Paraview, with or without python
# - Add packages to apt-get for building OpenFOAM's gcc and code documentation


# >>> DEFAULT SETTINGS <<< ---------------------------------------------------------
#make log options: LogOutput NoLog
LOG_OUTPUTS=LogOutput
LOG_OUTPUTS_LOGFILE="installOF.log"

#valid mirrors: ufpr internap mesh puzzle jaist optusnet kent garr nchc findClosest
mirror=findClosest

#valid upgrade options: DontUpgrade UpgradePackages
DOUPGRADE="DontUpgrade"

#fix tutorials: Fix DontFix
FIXTUTORIALS=Fix

#also build code documentation for OpenFOAM: (nothing) doc
BUILD_DOCUMENTATION=

#Use alias startFoam for on demand environment settings instead: yes no
USE_ALIAS_FOR_BASHRC=no

#use system's compiler or OpenFOAM's gcc: UseSystem UseOpenFOAM
COMPILERTOUSE=UseOpenFOAM

#interactive script: yes no
INTERACTIVE=yes

# >>> END OF DEFAULT SETTINGS <<< ----------------------------------------------------

#--------------------------------------------------------------
#Code ---------------------------------------------------------

set -e
arch=`uname -m`
version=`cat /etc/lsb-release | grep DISTRIB_RELEASE= | sed s/DISTRIB_RELEASE=/$1/g`

#enable this script's logging functionality ...
if [ "$LOG_OUTPUTS" == "LogOutput" ]; then
  exec 2>&1 > >(tee -a $LOG_OUTPUTS_LOGFILE)
  echo "This script has the automatic logging functionallity active."
  echo "What you see on screen is also saved in the file $LOG_OUTPUTS_LOGFILE"
fi

#FUNCTIONS SECTION ---------------------------------------------------------
function patchBashrcMultiCore()
{
tmpVar=$PWD
cd ~/OpenFOAM/OpenFOAM-1.6.x/etc/

echo '--- ../../bashrc  2009-11-21 00:00:47.502453988 +0000
+++ bashrc  2009-11-21 00:01:20.814519578 +0000
@@ -105,6 +105,20 @@
 : ${WM_MPLIB:=OPENMPI}; export WM_MPLIB
 
 
+#
+# Set the number of cores to build on
+#
+WM_NCOMPPROCS=1
+
+if [ -r /proc/cpuinfo ]
+then
+    WM_NCOMPPROCS=$(egrep "^processor" /proc/cpuinfo | wc -l)
+    [ $WM_NCOMPPROCS -le 8 ] || WM_NCOMPPROCS=8
+fi
+
+echo "Building on " $WM_NCOMPPROCS " cores"
+export WM_NCOMPPROCS
+
 # Run options (floating-point signal handling and memory initialisation)
 # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 export FOAM_SIGFPE=' | patch -p0

cd $tmpVar
unset tmpVar
}

function patchBashrcTo32()
{
tmpVar=$PWD
cd ~/OpenFOAM/OpenFOAM-1.6.x/etc/

echo '--- ../../bashrc  2009-11-21 00:00:47.502453988 +0000
+++ bashrc  2009-11-21 00:01:20.814519578 +0000
@@ -93,7 +93,7 @@
 # Compilation options (architecture, precision, optimised, debug or profiling)
 # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 # WM_ARCH_OPTION = 32 | 64
-: ${WM_ARCH_OPTION:=64}; export WM_ARCH_OPTION
+: ${WM_ARCH_OPTION:=32}; export WM_ARCH_OPTION
 
 # WM_PRECISION_OPTION = DP | SP
 : ${WM_PRECISION_OPTION:=DP}; export WM_PRECISION_OPTION' | patch -p0

cd $tmpVar
unset tmpVar
}

function patchSettingsToSystemCompiler()
{
tmpVar=$PWD
cd ~/OpenFOAM/OpenFOAM-1.6.x/etc/

echo '--- ../../settings.sh 2009-11-21 00:01:29.851902621 +0000
+++ settings.sh 2009-11-21 00:01:59.157391716 +0000
@@ -95,7 +95,7 @@
 # Select compiler installation
 # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 # compilerInstall = OpenFOAM | System
-compilerInstall=OpenFOAM
+compilerInstall=System
 
 case "${compilerInstall:-OpenFOAM}" in
 OpenFOAM)' | patch -p0

cd $tmpVar
unset tmpVar
}

#float comparison >=
function isleftlarger_or_equal()
{
  set +e
  a=$1
  b=$2
  if [ x`echo $a | awk '{ if ($1 >= '$b') {print "yes"}}'` == "xyes" ]; then
    return 1
  else
    return 0
  fi
  set -e
}

function calcestimate()
{
  set +e
  bogompis=`cat /proc/cpuinfo | grep bogomips | head -n 1 | sed s/bogomips.*:\ //`
  numcores=`egrep "^processor" /proc/cpuinfo | wc -l`
  return `echo '1250000 / ( '$bogompis'  * '$numcores' ) ' | bc`
  set -e
}
#END FUNCTIONS SECTION ---------------------------------------------------------



#INTERACTIVE SECTION  ----------------------------------
if  [ "$INTERACTIVE" == "yes" ]; then
  echo "-----------------------------------------------------"
  echo "--------- OpenFOAM 1.6.x Install for Ubuntu ---------"
  echo "-----------------------------------------------------"
  echo "Created by..................Mads Reck   		"
  echo "Revisions and updates.......Bruno Santos		"
  echo "                            Anton Kidess		"
  echo "                            Fabio Canesin		"
  echo "-----------------------------------------------------"
  echo "What is your Geographical location ? (if not in list, chose closest)"
  echo "1 - Brazil"
  echo "2 - US"
  echo "3 - Germany"
  echo "4 - Switzerland"
  echo "5 - Japan"
  echo "6 - Australia"
  echo "7 - UK"
  echo "8 - Italy"
  echo "9 - China/Taiwan"
  echo "10 - Automatic search for closest (might not provide real closest)"
  echo "11 - EXIT INSTALL"
  echo "-----------------------------------------------------"
  read casestat;
  case $casestat in
  1) mirror=ufpr;;
  2) mirror=internap;;
  3) mirror=mesh;;
  4) mirror=puzzle;;
  5) mirror=jaist;;
  6) mirror=optusnet;;
  7) mirror=kent;;
  8) mirror=garr;;
  9) mirror=nchc;;
  10) mirror=findClosest;;
  11) exit;;
  esac

  echo "------------------------------------------------------"
  echo "During the installation of Ubuntu packages, this script"
  echo "can upgrade the already existing Ubuntu packages, but "
  echo "this could bring some issues to your Ubuntu installation."
  echo "It does NOT upgrade Ubuntu itself, like from 9.04 to 9.10."
  echo ""
  echo "So, do you want this script to also upgrade the packages?"
  echo "(yes or no): "
  read casestat;
  case $casestat in
    yes | y | Y | Yes | YES) DOUPGRADE="UpgradePackages";;
    no | n | N | No | NO) DOUPGRADE="DontUpgrade";;
  esac
  echo "------------------------------------------------------"

  echo "------------------------------------------------------"
  echo "Build code documentation? (yes or no): "
  read casestat;
  case $casestat in
    yes | y | Y | Yes | YES) BUILD_DOCUMENTATION=doc;;
    *) BUILD_DOCUMENTATION=;;
  esac
  echo "------------------------------------------------------"

  echo "------------------------------------------------------"
  #give an option for using the system's compiler, but only if Ubuntu >= 9.04
  isleftlarger_or_equal $version 9.04
  if [ x"$?" == x"1" ]; then
    echo "Use Ubuntu's gcc compiler (will use OpenFOAM's otherwise)? (yes or no): "
    read casestat;
    case $casestat in
      yes | y | Y | Yes | YES) COMPILERTOUSE=UseSystem;;
      *) COMPILERTOUSE=UseOpenFOAM;;
    esac
  else
    echo "Will have to use OpenFOAM's gcc, because this Ubuntu is before 9.04"
    COMPILERTOUSE=UseOpenFOAM
  fi
  echo "------------------------------------------------------"

  echo "------------------------------------------------------"
  echo "Do you want the OpenFOAM environment to be set as default"
  echo "whenever you start a new terminal? (yes or no): "
  read casestat;
  case $casestat in
    yes | y | Y | Yes | YES) USE_ALIAS_FOR_BASHRC=no;;
    *)
      echo "You can run startFoam whenever you need OpenFOAM in a terminal."
      USE_ALIAS_FOR_BASHRC=yes;;
  esac
  echo "------------------------------------------------------"


fi
#END OF INTERACTIVE SECTION  ----------------------------------

if [ "$mirror" == "findClosest" ]; then
  echo "------------------------------------------------------"
  echo "Searching for the closest sourceforge mirror..."
  echo "It can take from 10s to 90s (estimated)..."
  echo "------------------------------------------------------"
  best_time=9999999
  #US mirror by default, in case the cycle breaks...
  mirror=internap
  for mirror_tmp in ufpr internap mesh puzzle jaist optusnet kent garr nchc; do
    timednow=`ping -Aqc 5 -s 120 $mirror_tmp.dl.sourceforge.net | sed -nr 's/.*time\ ([0-9]+)ms.*/\1/p'`
    echo "$mirror_tmp: $timednow ms"
    if [ $timednow -lt $best_time ]; then
      mirror=$mirror_tmp
      best_time=$timednow
    fi
  done
  echo "--- Mirror picked: $mirror"
  echo "------------------------------------------------------"
fi

#defining packages to download
THIRDPARTY_GENERAL="ThirdParty-1.6.General.gtgz"
if [ "$arch" == "x86_64" ]; then
  THIRDPARTY_BIN="ThirdParty-1.6.linux64Gcc.gtgz"
elif [ x`echo $arch | grep -e "i.86"` != "x" ]; then
  THIRDPARTY_BIN="ThirdParty-1.6.linuxGcc.gtgz"
else
  echo "Sorry, architecture not recognized, aborting."
  exit
fi

#define which folder to fix libraries
if [ "$version" == "9.10" ]; then
  if [ "$arch" == "x86_64" ]; then
    LIBRARY_PATH_TO_FIX="~/OpenFOAM/ThirdParty-1.6/gcc-4.3.3/platforms/linux64/lib64"
  elif [ x`echo $arch | grep -e "i.86"` != "x" ]; then
    LIBRARY_PATH_TO_FIX="~/OpenFOAM/ThirdParty-1.6/gcc-4.3.3/platforms/linux/lib"
  fi
fi

echo "------------------------------------------------------"
echo " Your system appears to be "$arch" Acting accordingly "
echo "------------------------------------------------------"
echo "Making sure that you have all needed libraries"
echo "------------------------------------------------------"
echo "--Installing dependencies ----------------------------"
echo "------------------------------------------------------"
sudo apt-get update -y -q=2
if [ "$DOUPGRADE" == "UpgradePackages" ]; then sudo apt-get upgrade -y -q=2; fi
sudo apt-get install -y -q=2 binutils-dev flex git git-core build-essential python-dev libqt4-dev libreadline5-dev wget zlib1g-dev cmake
#for Ubuntu 8.04, a few more packages are needed
isleftlarger_or_equal 8.10 $version
if [ x"$?" == x"1" ]; then
  sudo apt-get install -y -q=2 curl
fi


echo "------------------------------------------------------"
echo "Creating ~/OpenFOAM folder"
echo "------------------------------------------------------"
cd ~
if [ ! -d "OpenFOAM" ]; then mkdir OpenFOAM; fi
cd OpenFOAM

echo "------------------------------------------------------"
echo "Downloading ThirdParty stuff"
echo "------------------------------------------------------"
echo "Your system appears to be Ubuntu "$version". Acting accordingly"
echo "------------------------------------------------------"
if [ ! -e "$THIRDPARTY_GENERAL" ]; then wget http://downloads.sourceforge.net/foam/$THIRDPARTY_GENERAL?use_mirror=$mirror; fi
if [ ! -e "$THIRDPARTY_BIN" ]; then wget http://downloads.sourceforge.net/foam/$THIRDPARTY_BIN?use_mirror=$mirror; fi
echo "------------------------------------------------------"
echo "Untarring - this takes a while..."
echo "------------------------------------------------------"
tar xfz $THIRDPARTY_GENERAL
if [ "x$THIRDPARTY_BIN" != "x" ]; then tar xfz $THIRDPARTY_BIN; fi
echo "------------------------------------------------------"

#apply fix, only if it isn't to use the system's compiler
if [ "$version" == "9.10" -a "$COMPILERTOUSE" == "UseOpenFOAM" ]; then
  echo "-----------------------------------------------------"
  echo "Fixing library links"
  cd $LIBRARY_PATH_TO_FIX
  mv libstdc++.so.6 libstdc++.so.6.orig
  ln -s `locate libstdc++.so.6.0 | grep "^/usr/lib" | head -n 1` libstdc++.so.6
  mv libgcc_s.so.1 libgcc_s.so.1.orig
  ln -s `locate libgcc_s.so. | grep "^/lib" | head -n 1` libgcc_s.so.1
  cd ~/OpenFOAM
  echo "Fix up done"
  echo "------------------------------------------------------"
fi

echo "------------------------------------------------------"
echo "Retrieving OpenFOAM 1.6.x from git..."
echo "------------------------------------------------------"
ln -s  ~/OpenFOAM/ThirdParty-1.6 ~/OpenFOAM/ThirdParty-1.6.x
git clone http://repo.or.cz/r/OpenFOAM-1.6.x.git

#apply patches
echo "------------------------------------------------------"
echo "Applying patches to bashrc and settings.sh ..."
echo "------------------------------------------------------"
patchBashrcMultiCore #for faster builds on multi-core machines
if [ x`echo $arch | grep -e "i.86"` != "x" ]; then patchBashrcTo32; fi         #proper fix for running in 32bit
if [ "$COMPILERTOUSE" == "UseSystem" ]; then patchSettingsToSystemCompiler; fi #for using the system's compiler

echo "------------------------------------------------------"
echo "Activate OpenFOAM environment and add entry in ~/.bashrc"
echo "------------------------------------------------------"
cd OpenFOAM-1.6.x/
. ~/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc 

#nuke ~/.bashrc entries that have references to the same script
cat ~/.bashrc | grep -v 'OpenFOAM/OpenFOAM-1.6.x/etc/bashrc' > ~/.bashrc.new
cp ~/.bashrc ~/.bashrc.old
mv ~/.bashrc.new ~/.bashrc
if [ "$USE_ALIAS_FOR_BASHRC" == "yes" ]; then
  echo -e "alias startFoam=\". ~/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc\"" >> ~/.bashrc
else
  echo . ~/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc >> ~/.bashrc
fi

echo "------------------------------------------------------"
calcestimate
estimated_timed=$?
echo "Compiling OpenFOAM...output is in make.log"
echo "THIS CAN TAKE HOURS..."
echo "Estimated time it will take: $estimated_timed minutes."
echo "Total time that it did take will be shown upon completion."
echo "------------------------------------------------------"
time ./Allwmake $BUILD_DOCUMENTATION >make.log 2>&1

echo "------------------------------------------------------"
echo "Checking installation - you should see NO criticals..."
echo "------------------------------------------------------"
foamInstallationTest

if [ "$FIXTUTORIALS" == "Fix" ]; then
  echo "------------------------------------------------------"
  echo "Fixing call for bash in tutorials (default is dash in Ubuntu)"
  for file in `find ~/OpenFOAM/OpenFOAM-1.6.x/tutorials/ -name All*`; do
  mv $file $file.old
  sed '/^#!/ s/\/bin\/sh/\/bin\/bash/' $file.old > $file
  rm -f $file.old
  done
  echo "Fix up bash done"
  echo "------------------------------------------------------"
fi

set +e
