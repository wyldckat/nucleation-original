#!/bin/bash
#
#
# USAGE: $ chmod +x installOF.sh
#		 $ ./installOF.sh
#
# THIS SCRIPT IS UNDER GPLv3 LICENSE
# See script home at:
# http://code.google.com/p/openfoam-ubuntu
#
# Several key people have contributed for this project.
#-----------------------TODOS--------------------------------------
# 1 - Remake the interface using dialog < mark TODOS >
# 2 - Add packages to apt-get for building OpenFOAM's gcc and code documentation
# 3 - Add Qt 4.3.5 building, especially for Ubuntu 8.04 LTS - also has problems in 10.04!!
# 4 - Add building Paraview, with or without python
# 5 - add option to build OpenFOAM's gcc, but also will need patching of 3 missing files
# 6 - Multi-language support, since this script has only been tested in Ubuntu's standard english
# ps: Do you believe that is really necessary that?? English is standard. Nós dois falamos português
# por exemplo, e trocamos até mesmo emails em inglês, acredito que somente inglês é melhor para o projeto


# >>> DEFAULT SETTINGS <<< ---------------------------------------------------------

#TODO! - Path to Install OpenFOAM
#PATHOF=~/OpenFOAM

#Take care in dialogs with default settings already applied

#Mode of installation, provite at least: fresh, update, server, robot.
#INSTALLMODE=fresh
#make log options: Yes No
#LOG_OUTPUTS=Yes
#LOG_OUTPUTS_LOGFILE="installOF.log"
#valid mirrors: ufpr internap mesh puzzle jaist optusnet kent garr nchc findClosest
#mirror=findClosest
#valid upgrade options: 1 | 0 (on|off)
#DOUPGRADE=0
#fix tutorials: 1 | 0 (on|off)
#FIXTUTORIALS=1
#TODO! - lso build code documentation for OpenFOAM: 1 | 0 (on|off)
#BUILD_DOCUMENTATION=0
#Use alias startFoam for on demand environment settings instead: 1 | 0 (on|off)
#USE_ALIAS_FOR_BASHRC=1
#Use OpenFOAM's gcc: 1 | 0 (on|off)
#USE_OF_GCC=1
# >>> END OF DEFAULT SETTINGS <<< ----------------------------------------------------
#--------------------------------------------------------------
#Code ---------------------------------------------------------
#Detect architeture and ubuntu version
set -e
arch=`uname -m`
version=`cat /etc/lsb-release | grep DISTRIB_RELEASE= | sed s/DISTRIB_RELEASE=/$1/g`
#make dialog avaliable to use as "GUI", making sudo avaliable also
sudo apt-get install -q=2 dialog

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
#Presentation dialog
dialog --title "OpenFOAM-1.6.x Installer for Ubuntu" \
--msgbox "-------------------------------------------------------------------------\n
| =========               |                                               |\n
| \\      /  F ield        | OpenFOAM-1.6.x Installer for Ubuntu           |\n
|  \\    /   O peration    | Licensed under GPLv3                          |\n
|   \\  /    A nd          | Web: http://code.google.com/p/openfoam-ubuntu |\n
|    \\/     M anipulation | By: Fabio Canesin, Bruno Santos and Mads Reck |\n 
-------------------------------------------------------------------------" 0 0
#
#TODO!
#PATHOF=$(dialog --stdout \
#--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
#TODO! - Enable variable PATHOF in the rest of the code
#--inputbox 'Choose the install path: < default: ~/OpenFOAM >' 0 0)
# 

LOG_OUTPUTS=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
--menu 'Do you want to save a log of the script? < default: Yes >' 0 40 0 \
'Yes'   '' \
'No' '' )

INSTALLMODE=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"    \
--radiolist 'Choose the Install Mode: < default: fresh >' 0 0 0 \
'fresh' 'Make new Install' on  \
'update'    'Re-make from git repository - TODO!!'   off \
'robot'   'Create automated installer - TODO!!!'           off \
'server'    'Paraview with: -GUI +MPI - TODO!!!'    off )

SETTINGSOPTS=$(dialog --stdout --separate-output \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
--checklist "Choose Install settings: < Space to select ! >" 15 50 5 \
1 "Do apt-get upgrade" off \
2 "Fix tutorials" on \
3 "Build OpenFOAM docs" off \
4 "Use startFoam alias" on \
5 "Use OpenFOAM gcc compiler" on )

# Take care of <Cancel> and <Esc>
if [ "$?" != "0" ] ; then exit ; fi
DOUPGRADE=0 ; FIXTUTORIALS=0 ; BUILD_DOCUMENTATION=0
USE_ALIAS_FOR_BASHRC=0 ; USE_OF_GCC=0
for setting in $SETTINGSOPTS ; do
if [ $setting == 1 ] ; then DOUPGRADE=1 ; fi
if [ $setting == 2 ] ; then FIXTUTORIALS=1 ; fi
if [ $setting == 3 ] ; then BUILD_DOCUMENTATION=1 ; fi
if [ $setting == 4 ] ; then USE_ALIAS_FOR_BASHRC=1 ; fi
if [ $setting == 5 ] ; then USE_OF_GCC=1 ; fi
done

dialog --sleep 4 \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
--title 'Install settings are: < 1-Yes 0-No >' \
--infobox "Log : $LOG_OUTPUTS\n \
Install mode: $INSTALLMODE\n \
Run apt-get upgrade ? $DOUPGRADE\n \
Fix tutorials ? $FIXTUTORIALS\n \
Build documentation ? $BUILD_DOCUMENTATION\n \
Use startFoam alias ? $USE_ALIAS_FOR_BASHRC\n \
Use OpenFOAM gcc ? $USE_OF_GCC\n" 9 50

#Enable this script's logging functionality ...
if [ "$LOG_OUTPUTS" == "Yes" ]; then
  exec 2>&1 > >(tee -a $LOG_OUTPUTS_LOGFILE)
fi
mirror=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
--menu 'Choose your location for mirror selection? < default: autodetect >' 0 40 0 \
findClosest 'Autodetect closest' \
ufpr 'Brazil' \
internap 'US' \
mesh 'Germany' \
puzzle 'Switzerlande' \
jaist 'Japan' \
optusnet 'Australia' \
kent 'UK' \
garr 'Italy' \
nchc 'China/Taiwan' )

#END OF INTERACTIVE SECTION  ----------------------------------

if [ "$mirror" == "findClosest" ]; then
(echo "Searching for the closest mirror..."
  echo "It can take from 10s to 90s (estimated)..."
  echo "--------------------"
  best_time=9999
  for mirror_tmp in ufpr internap mesh puzzle jaist optusnet kent garr nchc; do
    timednow=`ping -Aqc 5 -s 120 $mirror_tmp.dl.sourceforge.net | sed -nr 's/.*time\ ([0-9]+)ms.*/\1/p'`
    echo "$mirror_tmp: $timednow ms"
    if [ $timednow -lt $best_time ]; then
      mirrorf=$mirror_tmp
      best_time=$timednow
    fi
  done
  echo "*---Mirror picked: $mirrorf" ) > temp.log &
mirror=
while [ "$mirror" == "" ] ; do
mirror=`grep "picked:" temp.log | cut -c20-`
dialog --sleep 1 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
--title "Mirror selector" \
--infobox "`cat temp.log`" 15 50
done
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
if [ "$DOUPGRADE" == "1" ]; then sudo apt-get upgrade -y -q=2; fi
sudo apt-get install -y -q=2 binutils-dev flex git-core build-essential python-dev libqt4-dev libreadline5-dev wget zlib1g-dev cmake
#for Ubuntu 8.04, a few more packages are needed
isleftlarger_or_equal 8.10 $version
if [ x"$?" == x"1" ]; then
  sudo apt-get install -y -q=2 curl
fi
cd ~
if [ ! -d "OpenFOAM" ]; then mkdir OpenFOAM; fi
cd OpenFOAM

if [ ! -e "$THIRDPARTY_GENERAL" ]; then 
	urladr=http://downloads.sourceforge.net/foam/$THIRDPARTY_GENERAL?use_mirror=$mirror
	wget $urladr 2>&1 | sed -u `s/.*\ \([0-9]\+%\)\ \+\([0-9.]\+\ [KMB\/s]\+\)$/\1\n# Downloading \2/` | dialog --title="Downloading $THIRDPARTY_GENERAL" --gauge 10 40 0
fi
if [ ! -e "$THIRDPARTY_BIN" ]; then 
	urladr=http://downloads.sourceforge.net/foam/$THIRDPARTY_BIN?use_mirror=$mirror
	wget $urladr 2>&1 | sed -u `s/.*\ \([0-9]\+%\)\ \+\([0-9.]\+\ [KMB\/s]\+\)$/\1\n# Downloading \2/` | dialog --title="Downloading $THIRDPARTY_BIN" --gauge 10 40 0
fi
fi
tar xfz $THIRDPARTY_GENERAL
if [ "x$THIRDPARTY_BIN" != "x" ]; then tar xfz $THIRDPARTY_BIN; fi
echo "------------------------------------------------------"

#apply fix, only if it isn't to use the system's compiler
if [ "$version" == "9.10" -a "$USE_OF_GCC" == "1" ]; then
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
if [ "$USE_OF_GCC" == "0" ]; then patchSettingsToSystemCompiler; fi #for using the system's compiler

echo "------------------------------------------------------"
echo "Activate OpenFOAM environment and add entry in ~/.bashrc"
echo "------------------------------------------------------"
cd OpenFOAM-1.6.x/
. ~/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc 

#nuke ~/.bashrc entries that have references to the same script
cat ~/.bashrc | grep -v 'OpenFOAM/OpenFOAM-1.6.x/etc/bashrc' > ~/.bashrc.new
cp ~/.bashrc ~/.bashrc.old
mv ~/.bashrc.new ~/.bashrc
if [ "$USE_ALIAS_FOR_BASHRC" == "1" ]; then
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

if [ "$FIXTUTORIALS" == "1" ]; then
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
