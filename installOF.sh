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
# Several people have contributed for this project on http://www.cfd-online.com
#-----------------------TODOS--------------------------------------
# 1 - Remake the interface using dialog < mark TODOS >
# 2 - Add packages to apt-get for building OpenFOAM's gcc and code documentation
# 3 - Add Qt 4.3.5 building, especially for Ubuntu 8.04 LTS - also has problems in 10.04!!
# 4 - Add building Paraview, with or without python
# 5 - add option to build OpenFOAM's gcc, but also will need patching of 3 missing files
# 6 - Multi-language support, since this script has only been tested in Ubuntu's standard english
# ps: Do you believe that is really necessary that?? English is standard.

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
|    \\/     M anipulation | By: Fabio Canesin and Bruno Santos            |\n
|                         | Based on orginial work from Mads Reck         |\n
-------------------------------------------------------------------------" 12 80
#
#TODO!
#Make possible to user choose the path of installation
#PATHOF=$(dialog --stdout \
#--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
#TODO! - Enable variable PATHOF in the rest of the code
#--inputbox 'Choose the install path: < default: ~/OpenFOAM >' 0 0)
# 

#Loging option Dialog
LOG_OUTPUTS=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
--menu 'Do you want to save a log of the script? < default: Yes >' 0 40 0 \
'Yes'   '' \
'No' '' )

#Installating mode dialog
INSTALLMODE=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"    \
--radiolist 'Choose the Install Mode: < default: fresh >' 0 0 0 \
'fresh' 'Make new Install' on  \
'update'    'Re-make from git repository - TODO!!'   off \
'robot'   'Create automated installer - TODO!!!'           off \
'server'    'Paraview with: -GUI +MPI - TODO!!!'    off )

#Settings choosing Dialog
SETTINGSOPTS=$(dialog --stdout --separate-output \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
--checklist "Choose Install settings: < Space to select ! >" 15 50 5 \
1 "Do apt-get upgrade" off \
2 "Fix tutorials" on \
3 "Build OpenFOAM docs" off \
4 "Use startFoam alias" on \
5 "Use OpenFOAM gcc compiler" on )

#Take care of unpack settings from SETTINGSOPTS
DOUPGRADE=No ; FIXTUTORIALS=No ; BUILD_DOCUMENTATION=
USE_ALIAS_FOR_BASHRC=No ; USE_OF_GCC=No
for setting in $SETTINGSOPTS ; do
if [ $setting == 1 ] ; then DOUPGRADE=Yes ; fi
if [ $setting == 2 ] ; then FIXTUTORIALS=Yes ; fi
if [ $setting == 3 ] ; then BUILD_DOCUMENTATION=doc ; fi
if [ $setting == 4 ] ; then USE_ALIAS_FOR_BASHRC=Yes ; fi
if [ $setting == 5 ] ; then USE_OF_GCC=Yes ; fi
done

#Enable this script's logging functionality ...
if [ "$LOG_OUTPUTS" == "Yes" ]; then
  exec 2>&1 > >(tee -a installOF.log)
fi

#Mirror selection dialog
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

#Detect and take care of fastest mirror
if [ "$mirror" == "findClosest" ]; then
(echo "Searching for the closest mirror..."
  echo "It can take from 10s to 90s (estimated)..."
  echo "--------------------"
  echo "It can provide fake closest!"
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
  echo "*---Mirror picked: $mirrorf" ) > tempmirror.log &
mirror=
while [ "$mirror" == "" ] ; do
mirror=`grep "picked:" tempmirror.log | cut -c20-`
dialog --sleep 1 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
--title "Mirror selector" \
--infobox "`cat tempmirror.log`" 17 50
done
rm -rf tempmirror.log
fi
#END OF INTERACTIVE SECTION  ----------------------------------

clear
#Show to user the detected settings, last chance to cancel the installer
dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
--title "Final settings - <ESC> to abort the Installer" \
--msgbox "-------------------------------------------------------------------------\n
| =========   Detected thath you are running: Ubuntu $version - $arch\n
| \\      /    The choosed mirror is: $mirror\n
|  \\    /     Loging: $LOG_OUTPUTS\n
|   \\  /      Install mode: $INSTALLMODE\n
|    \\/       Run apt-get upgrade ? $DOUPGRADE\n
|             Fix tutorials ? $FIXTUTORIALS\n
| *installOF* Build documentation ? $BUILD_DOCUMENTATION\n
| *settings*  Use startFoam alias ? $USE_ALIAS_FOR_BASHRC\n
|             Use OpenFOAM gcc ? $USE_OF_GCC\n
-------------------------------------------------------------------------\n
!For more info see documentation on code.google.com/p/openfoam-ubuntu" 16 80
clear

#Defining packages to download
THIRDPARTY_GENERAL="ThirdParty-1.6.General.gtgz"
if [ "$arch" == "x86_64" ]; then
  THIRDPARTY_BIN="ThirdParty-1.6.linux64Gcc.gtgz"
elif [ x`echo $arch | grep -e "i.86"` != "x" ]; then
  THIRDPARTY_BIN="ThirdParty-1.6.linuxGcc.gtgz"
else
  echo "Sorry, architecture not recognized, aborting."
  exit
fi

#Define which folder to fix libraries
if [ "$version" != "8.04" ]; then
  if [ "$arch" == "x86_64" ]; then
    LIBRARY_PATH_TO_FIX="~/OpenFOAM/ThirdParty-1.6/gcc-4.3.3/platforms/linux64/lib64"
  elif [ x`echo $arch | grep -e "i.86"` != "x" ]; then
    LIBRARY_PATH_TO_FIX="~/OpenFOAM/ThirdParty-1.6/gcc-4.3.3/platforms/linux/lib"
  fi
fi

#Do update and if choosed upgrade

sudo apt-get update -y -q=1
if [ "$DOUPGRADE" == "Yes" ]; then
sudo apt-get upgrade -y
fi
sudo apt-get install -y -q=1 binutils-dev flex git-core build-essential python-dev libqt4-dev libreadline5-dev wget zlib1g-dev cmake

#for Ubuntu 8.04, a few more packages are needed
isleftlarger_or_equal 8.10 $version
if [ x"$?" == x"1" ]; then
  sudo apt-get install -y -q=2 curl
fi 

cd ~
if [ ! -d "OpenFOAM" ]; then mkdir OpenFOAM; fi
cd OpenFOAM

#Download Thidparty files
if [ ! -e "$THIRDPARTY_GENERAL" ]; then 
	urladr=http://downloads.sourceforge.net/foam/$THIRDPARTY_GENERAL?use_mirror=$mirror
    wget $urladr > tempwget1.log &
fi
if [ ! -e "$THIRDPARTY_BIN" ]; then 
	urladr=http://downloads.sourceforge.net/foam/$THIRDPARTY_BIN?use_mirror=$mirror
	wget $urladr > tempwget2.log &
fi
fi
tar xfz $THIRDPARTY_GENERAL
if [ "x$THIRDPARTY_BIN" != "x" ]; then tar xfz $THIRDPARTY_BIN; fi
echo "------------------------------------------------------"
exit
#apply fix, only if it isn't to use the system's compiler
if [ "$version" == "9.10" -a "$USE_OF_GCC" == "Yes" ]; then
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

#Apply patches
echo "------------------------------------------------------"
echo "Applying patches to bashrc and settings.sh ..."
echo "------------------------------------------------------"
patchBashrcMultiCore #for faster builds on multi-core machines
if [ x`echo $arch | grep -e "i.86"` != "x" ]; then patchBashrcTo32; fi #proper fix for running in 32bit
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
if [ "$USE_ALIAS_FOR_BASHRC" == "Yes" ]; then
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

if [ "$FIXTUTORIALS" == "Yes" ]; then
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
