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
#TODO 1 - Add Qt 4.3.5 building, especially for Ubuntu 8.04 LTS - also has problems in 10.04!!
#TODO 2 - Add building Paraview, with or without python and MPI
#TODO 3 - add option to build OpenFOAM's gcc, but also will need patching of 3 missing files
#TODO 4 - Multi-language support, since this script has only been tested in Ubuntu's standard english

#Code ---------------------------------------------------------

#block attempts to run this script as superuser. If the user wants to install in a system folder, 
#let him/her set proper permissions to that folder first!
if [ $(/usr/bin/id -u) -eq 0 ]; then
    echo -e "Please do not run this script with superuser/root powers!!\n"
    echo "If you need to install OpenFOAM in a system folder,"
    echo "please change the permissions to the desired folder"
    echo "for this installation only. This way we reduce the"
    echo "margin of error this script may incur."
    exit
fi

#Detect architeture and ubuntu version
set -e
arch=`uname -m`
version=`cat /etc/lsb-release | grep DISTRIB_RELEASE= | sed s/DISTRIB_RELEASE=/$1/g`

#FUNCTIONS SECTION ---------------------------------------------------------

#-- PATCHING FUNCTIONS -----------------------------------------------------

#Patch to compile using multicore
function patchBashrcMultiCore()
{
tmpVar=$PWD
cd $PATHOF/OpenFOAM/OpenFOAM-1.6.x/etc/

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

#Patch to work on 32-bit versions
function patchBashrcTo32()
{
tmpVar=$PWD
cd $PATHOF/OpenFOAM/OpenFOAM-1.6.x/etc/

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

#Patch to use System compiler
function patchSettingsToSystemCompiler()
{
tmpVar=$PWD
cd $PATHOF/OpenFOAM/OpenFOAM-1.6.x/etc/

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

#Patch paraFoam script
function patchParaFoamScript()
{
tmpVar=$PWD
cd $PATHOF/OpenFOAM/OpenFOAM-1.6.x/bin/

echo '--- ../../paraFoam  2010-04-11 01:38:34.000000000 +0100
+++ paraFoam  2010-04-11 01:38:18.000000000 +0100
@@ -75,6 +75,8 @@
     esac
 done
 
+export LC_ALL=C
+
 # get a sensible caseName
 caseName=${PWD##*/}
 caseFile="$caseName.OpenFOAM"
' | patch -p0

cd $tmpVar
unset tmpVar
}

#-- END PATCHING FUNCTIONS -------------------------------------------------


#-- UTILITY FUNCTIONS ------------------------------------------------------

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

#is package installed
function ispackage_installed()
{
  if [ x`dpkg-query -W -f='${Status}\n' $1 | grep not-installed` == "x" ]; then
    return 1
  else
    return 0
  fi
  set -e
}

#is the system is running in english or not
function issystem_english()
{
  set +e
  if [ x`echo $LANG | grep ^en` != "x" ]; then
    return 1
  else
    return 0
  fi
  set -e
}

#returns time in minutes
function calcestimate()
{
  set +e
  bogompis=`cat /proc/cpuinfo | grep bogomips | head -n 1 | sed s/bogomips.*:\ //`
  numcores=`egrep "^processor" /proc/cpuinfo | wc -l`
  return `echo '1250000 / ( '$bogompis'  * '$numcores' ) ' | bc`
  set -e
}

function prune_packages_to_install()
{
  PACKAGES_TO_INSTALL_TMP=""
  for package in $PACKAGES_TO_INSTALL
  do
    ispackage_installed $package
    if [ x"$?" == x"0" ]; then
      PACKAGES_TO_INSTALL_TMP="$PACKAGES_TO_INSTALL_TMP $package"
    fi
  done
  PACKAGES_TO_INSTALL=$PACKAGES_TO_INSTALL_TMP
  unset PACKAGES_TO_INSTALL_TMP
}

function cd_openfoam()
{
  cd $PATHOF
}
#-- END UTILITY FUNCTIONS --------------------------------------------------

#-- MAIN FUNCTIONS ---------------------------------------------------------

#setup sudo policy for this script
#REASON: not always does the user have superuser powers, or maybe the user doesn't fully trust us. 
#Either way, using sudo whithin the script could be a security hazard waiting to happen :(
function ask_for_sudo_policy()
{
  echo '-----------------------------------------------------------'
  echo '  Welcome to the OpenFOAM-1.6.x Installer for Ubuntu  '
  echo ' '
  echo '  Before starting this script, it is necessary to define'
  echo 'what policy should be used by this script, when installing'
  echo 'new packages in Ubuntu. More specifically, superuser access'
  echo 'will be required for installing packages, by calling the '
  echo 'command "sudo".'
  echo '  If you have superuser permissions and trust this script '
  echo 'to use the sudo command, then type yes then hit return. '
  echo -e 'Otherwise, type no:'
  echo "(yes or no): "
  read casestat;
  case $casestat in
    yes | y | Y | Yes | YES) SHOW_SUDO_COMMANDS_ONLY="YES";;
    no | n | N | No | NO) SHOW_SUDO_COMMANDS_ONLY="";;
  esac
  echo "------------------------------------------------------"
}

#install dialog or abort if not possible
function install_dialog_package()
{
  ispackage_installed dialog
  if [ x"$?" == x"0" ]; then
    #if permission granted
    if [ x"$SHOW_SUDO_COMMANDS_ONLY" == "x" ]; then
      #tell the user that dialog has to be installed, and request permission to install it
      echo 'This script needs the package "dialog" to be installed. It will execute the command:'
      echo '      sudo apt-get install dialog'
      echo 'which will (or should) request for your sudo password...'
      sudo apt-get install -q=2 dialog
    else
      #tell the user that dialog has to be installed, and request permission to install it
      echo 'This script needs the package "dialog" to be installed. Please execute the following command:'
      echo '      sudo apt-get install dialog'
      echo ' '
      echo 'Please open a new terminal and execute the command above.'
      echo 'If you do not have superuser powers to run the "sudo" command, then please request your system administrator to run the command above.'
      echo ' '
      echo 'When the installation is complete, please press enter to continue this script.'
      echo 'If you don''t want to install it now, press Ctrl+C.'
      read aaa_tmp_var
      unset aaa_tmp_var
    fi
  fi
}

#Defining packages to download
function define_packages_to_download()
{
  THIRDPARTY_GENERAL="ThirdParty-1.6.General.gtgz"
  if [ "$arch" == "x86_64" ]; then
    THIRDPARTY_BIN="ThirdParty-1.6.linux64Gcc.gtgz"
  elif [ x`echo $arch | grep -e "i.86"` != "x" ]; then
    THIRDPARTY_BIN="ThirdParty-1.6.linuxGcc.gtgz"
  else
    echo "Sorry, architecture not recognized, aborting."
    exit
  fi
}

#install packages in Ubuntu
function install_ubuntu_packages()
{
  #define which packages need to be installed
  PACKAGES_TO_INSTALL="binutils-dev flex git-core build-essential python-dev libqt4-dev libreadline5-dev wget zlib1g-dev cmake"

  #for Ubuntu 8.04, a few more packages are needed
  isleftlarger_or_equal 8.10 $version
  if [ x"$?" == x"1" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL curl"
  fi

  #for documentation, these are necessary
  if [ "$BUILD_DOCUMENTATION" == "doc" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL doxygen graphviz"
  fi

  #TODO! for building gcc, these are necessary
  #if [ "$" == "" ]; then
  #  PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL texinfo byacc bison"
  #fi
  
  #now remove the ones that are already installed
  prune_packages_to_install
  
  #only show commands for installation if any packages are missing!
  if [ x"$PACKAGES_TO_INSTALL" != "x" ]; then

    #if permission granted
    if [ x"$SHOW_SUDO_COMMANDS_ONLY" == "x" ]; then

      echo 'The command "sudo apt-get update -y -q=1" is now going to be executed. Please provide sudo password if it asks you.'
      sudo apt-get update -y -q=1
      if [ "$DOUPGRADE" == "Yes" ]; then
        echo 'The command "sudo apt-get upgrade -y" is now going to be executed.'
        sudo apt-get upgrade -y
      fi
      
      echo 'The command:'
      echo "    sudo apt-get install -y -q=1 $PACKAGES_TO_INSTALL"
      echo 'is now going to be executed.'
      sudo apt-get install -y -q=1 $PACKAGES_TO_INSTALL
      
    else

      echo 'Please run the following commands in another terminal or ask your system''s administrator to run them:'
      echo '    sudo apt-get update -y -q=1'
      if [ "$DOUPGRADE" == "Yes" ]; then
        echo '    sudo apt-get upgrade -y'
      fi
      echo "    sudo apt-get install -y -q=1 $PACKAGES_TO_INSTALL"
      echo ' '
      echo 'When the installation is complete, please press enter to continue this script.'
      echo 'If you don''t want to install it now, press Ctrl+C.'
      read aaa_tmp_var
      unset aaa_tmp_var

    fi

  fi
  
  #now remove the ones that are already installed again, to confirm that all have been installed!
  prune_packages_to_install
  if [ x"$PACKAGES_TO_INSTALL" != "x" ]; then
    echo -e "\n\nWARNING: The following packages aren't installed:"
    echo "  $PACKAGES_TO_INSTALL"
    echo -e "\nDo you want to try and continue the OpenFOAM installation? (yes or no): "
    read casestat;
    case $casestat in
      no | n | N | No | NO)
        echo "Installation aborted."
        set +e
        exit 1
        ;;
    esac
  fi  
}

#Create OpenFOAM folder at $PATHOF
function create_OpenFOAM_folder()
{
  if [ ! -d "$PATHOF" ]; then
    mkdir -p $PATHOF
  fi
}

#Download necessary files
function download_files()
{
  cd_openfoam #this is a precautionary measure

  #Download Third Party files for detected system and selected mirror
  #download Third Party sources
  if [ ! -e "$THIRDPARTY_GENERAL" ]; then 
    urladr=http://downloads.sourceforge.net/foam/$THIRDPARTY_GENERAL?use_mirror=$mirror
    wget $urladr
  fi

  #download Third Party binaries, but only if requested and necessary!
  if [ "x$THIRDPARTY_BIN" != "x" ]; then
    if [ ! -e "$THIRDPARTY_BIN" ]; then 
      urladr=http://downloads.sourceforge.net/foam/$THIRDPARTY_BIN?use_mirror=$mirror
      wget $urladr
    fi
  fi
}

#Unpack downloaded files
function unpack_downloaded_files()
{
  cd_openfoam #this is a precautionary measure

  echo "------------------------------------------------------"
  echo "Untar files -- This can take time"
  tar xfz $THIRDPARTY_GENERAL
  
  #check if $THIRDPARTY_BIN is provided, because one could want to build from sources
  if [ "x$THIRDPARTY_BIN" != "x" ]; then 
    tar xfz $THIRDPARTY_BIN
  fi
  echo "------------------------------------------------------"
}

#git clone OpenFOAM
function OpenFOAM_git_clone()
{
  cd_openfoam #this is a precautionary measure

  echo "------------------------------------------------------"
  echo "Retrieving OpenFOAM 1.6.x from git..."
  echo "------------------------------------------------------"
  ln -s $PATHOF/OpenFOAM/ThirdParty-1.6 $PATHOF/OpenFOAM/ThirdParty-1.6.x
  git clone http://repo.or.cz/r/OpenFOAM-1.6.x.git
}

#apply patches and fixes
function apply_patches_fixes()
{
  cd_openfoam #this is a precautionary measure

  #FIXES ------
  
  #fix links to proper libraries for gcc, as long as the OpenFOAM's precompiled version is used
  isleftlarger_or_equal $version 9.10
  if [ x"$?" == x"1" -a "$USE_OF_GCC" == "Yes" ]; then
    #Define which folder to fix libraries
    if [ "$version" != "8.04" ]; then
      if [ "$arch" == "x86_64" ]; then
        LIBRARY_PATH_TO_FIX=${PATHOF}/ThirdParty-1.6/gcc-4.3.3/platforms/linux64/lib64
      elif [ x`echo $arch | grep -e "i.86"` != "x" ]; then
        LIBRARY_PATH_TO_FIX=${PATHOF}/ThirdParty-1.6/gcc-4.3.3/platforms/linux/lib
      fi
    fi

    echo "-----------------------------------------------------"
    echo "Fixing library links"
    cd $LIBRARY_PATH_TO_FIX
    mv libstdc++.so.6 libstdc++.so.6.orig
    ln -s `locate libstdc++.so.6.0 | grep "^/usr/lib" | head -n 1` libstdc++.so.6
    mv libgcc_s.so.1 libgcc_s.so.1.orig
    ln -s `locate libgcc_s.so. | grep "^/lib" | head -n 1` libgcc_s.so.1
    echo "Fix up done"
    echo "------------------------------------------------------"
  fi

  cd_openfoam #this is a precautionary measure

  #PATCHES ----
  #Apply patches from defined functions
  echo "------------------------------------------------------"
  echo "Applying patches to bashrc and settings.sh ..."
  echo "------------------------------------------------------"
  patchBashrcMultiCore #for faster builds on multi-core machines
  #proper fix for running in 32bit
  if [ x`echo $arch | grep -e "i.86"` != "x" ]; then
    patchBashrcTo32
  fi
  #Fix for using the system's compiler
  if [ "$USE_OF_GCC" == "No" ]; then
    patchSettingsToSystemCompiler
  fi #for using the system's compiler
  
  #apply patch for paraFoam, for when the running language 
  #isn't the standard english!
  issystem_english
  if [ x"$?" != x"1" ]; then
    patchParaFoamScript
  fi
}

#Activate OpenFOAM environment
function setOpenFOAMEnv()
{
  echo "------------------------------------------------------"
  echo "Activate OpenFOAM environment"
  echo "------------------------------------------------------"
  cd OpenFOAM-1.6.x/
  . $PATHOF/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc 
}

#Add OpenFOAM's bashrc entry in $PATHOF/.bashrc
function add_openfoam_to_bashrc()
{
  echo "------------------------------------------------------"
  echo "Add OpenFOAM's bashrc entry in $PATHOF/.bashrc"
  echo "------------------------------------------------------"

  #nuke ~/.bashrc entries that have references to the same script
  cat ~/.bashrc | grep -v 'OpenFOAM/OpenFOAM-1.6.x/etc/bashrc' > ~/.bashrc.new
  cp ~/.bashrc ~/.bashrc.old
  mv ~/.bashrc.new ~/.bashrc
  if [ "$USE_ALIAS_FOR_BASHRC" == "Yes" ]; then
    echo -e "alias startFoam=\". $PATHOF/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc\"" >> ~/.bashrc
  else
    echo ". $PATHOF/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc" >> ~/.bashrc
  fi
}

#do an Allwmake on OpenFOAM 1.6.x
function allwmake_openfoam()
{
  #set up environment, just in case we forget about it!
  if [ x"$WM_PROJECT_DIR" == "x" ]; then
    setOpenFOAMEnv
  fi

  cd $WM_PROJECT_DIR

  echo "------------------------------------------------------"
  calcestimate
  estimated_timed=$?
  echo "Compiling OpenFOAM...output is in $WM_PROJECT_DIR/make.log"
  echo "WARNING: THIS CAN TAKE HOURS..."
  echo "Estimated time it will take: $estimated_timed minutes."
  echo "Total time that it did take will be shown upon completion."
  echo "Started at: `date`"
  echo "------------------------------------------------------"
  bash -c "time ./Allwmake $BUILD_DOCUMENTATION >make.log" 2>&1
  #bash -c is the only way I got for getting time results straight to display and also logged
  echo "Build complete at: `date`"
}

function continue_after_failed_openfoam()
{
  if [ x"$FOAMINSTALLFAILED" != "x" ]; then
    FOAMINSTALLFAILED_BUTCONT="No"
    echo "Although the last seems to have failed, do you wish to continue with the remaining steps?"
    # echo "Missing steps:"
    #TODO: is Qt and Paraview in the list of yet "to do"?
    echo "Continue? (yes or no): "
    read casestat;
    case $casestat in
      yes | y | Y | Yes | YES) FOAMINSTALLFAILED_BUTCONT="Yes";;
    esac
    unset casestat
  fi
}

#check if the installation is complete
function check_installation()
{
  #set up environment, just in case we forget about it!
  if [ x"$WM_PROJECT_DIR" == "x" ]; then
    setOpenFOAMEnv
  fi

  cd $WM_PROJECT_DIR

  echo "------------------------------------------------------"
  echo "Checking installation - you should see NO criticals..."
  echo "------------------------------------------------------"
  foamInstallationTest | tee foamIT.log
  echo -e "\n\nThis report has been saved in file $WM_PROJECT_DIR/foamIT.log"

  #if issues found then generate "bug report" and request that the user reports it!
  if [ x`cat foamIT.log | grep "Critical systems ok"` == "x" ]; then
    FOAMINSTALLFAILED="Yes"
    echo -e "\nSadly there have been some critical issues detected by OpenFOAM's foamInstallationTest script."
    echo "A full report file can be generated so you can post it at this forum thread:"
    echo "  http://www.cfd-online.com/Forums/openfoam-installation/73805-openfoam-1-6-x-installer-ubuntu.html"
    echo -e '\nYou can also verify the thread for other people who might have had the same problems.'
    echo "So, do you want to generate a report file for attaching to your post? (yes or no): "
    read casestat;
    case $casestat in
      yes | y | Y | Yes | YES)
        FILES_TO_REPORT="foamIT.log make.log"
        if [ "$LOG_OUTPUTS" == "Yes" ]; then
          FILES_TO_REPORT="$FILES_TO_REPORT $LOG_OUTPUTS_FILE_LOCATION"
        fi
        echo "Compressing file $WM_PROJECT_DIR/report.tar.gz with files: $FILES_TO_REPORT"
        if [ -e "report.tar.gz" ]; then rm -f report.tar.gz; fi
        tar -czf report.tar.gz $FILES_TO_REPORT
        echo "Compression complete. Please attach this file to your report about the bad installation."
        unset FILES_TO_REPORT
        ;;
    esac
    unset casestat
    
    continue_after_failed_openfoam
  fi
}

function fix_tutorials()
{
  #TODO! Confirm if the fix "find then do while" does the trick
  if [ "$FIXTUTORIALS" == "Yes" ]; then
    #set up environment, just in case we forget about it!
    if [ x"$FOAM_TUTORIALS" == "x" ]; then
      setOpenFOAMEnv
    fi

    echo "------------------------------------------------------"
    echo "Fixing call for bash in tutorials (default is dash in Ubuntu)"
    find $FOAM_TUTORIALS/ -name All* | \
    while read file
    do
      mv $file $file.old
      sed '/^#!/ s/\/bin\/sh/\/bin\/bash/' $file.old > $file
      rm -f $file.old
    done
    echo "Fix up bash done"
    echo "------------------------------------------------------"
  fi
}

#final messages and instructions for when we do a clean install...
#whether it goes well or not
function final_messages_for_clean_install()
{
  if [ x"$FOAMINSTALLFAILED" == "x" ]; then

    #If using bash alias, inform to use it to run!
    if [ "$USE_ALIAS_FOR_BASHRC" == "Yes" ]; then
      echo "Installation complete - You have choose to use bash alias"
      echo "Before running OpenFOAM on a new terminal/console, type: startFoam"
      echo "The OpenFOAM environment is ready to be used."
      echo "------------------------------------------------------"
    else
      echo "Installation complete"
      echo "The OpenFOAM environment is ready to be used."
      echo "------------------------------------------------------"
    fi
  
  else

    echo "Installation failed. Please don't forget to check the provided forum link for solutions on the provided link, and/or report the error."
    if [ "$USE_ALIAS_FOR_BASHRC" == "Yes" ]; then
      echo "Nonetheless, next time you launch a new terminal/console, you can set up the OpenFOAM environment by typing: startFoam"
    else
      echo "Nonetheless, next time you launch a new terminal/console, the OpenFOAM environment will be ready to be used."
    fi
    echo "------------------------------------------------------"

  fi
}

function OpenFOAM_git_pull()
{
  #set up environment, just in case we forget about it!
  if [ x"$WM_PROJECT_DIR" == "x" ]; then
    setOpenFOAMEnv
  fi

  cd $WM_PROJECT_DIR
  
  echo "------------------------------------------------------"
  echo "Let's do a git pull"
  echo "------------------------------------------------------"
  git pull
}

#-- END MAIN FUNCTIONS -----------------------------------------------------

#END FUNCTIONS SECTION -----------------------------------------------------

#ask the user for what policy to use for running sudo
ask_for_sudo_policy

#make dialog avaliable to use as "GUI", making sudo avaliable if it is installed
install_dialog_package

#INTERACTIVE SECTION  ----------------------------------

#Presentation dialog
dialog --title "OpenFOAM-1.6.x Installer for Ubuntu" \
--msgbox "-------------------------------------------------------------------\n
| =========              |\n
| \\      / F ield        | OpenFOAM-1.6.x Installer for Ubuntu\n
|  \\    /  O peration    | Licensed under GPLv3\n
|   \\  /   A nd          | Web: http://code.google.com/p/openfoam-ubuntu\n
|    \\/    M anipulation | By: Fabio Canesin and Bruno Santos\n
|                        | Based on orginial work from Mads Reck\n
-----------------------------------------------------------------------" 11 80
#
#TODO!
#Make possible to user choose the path of installation
PATHOF=$HOME/OpenFOAM
#PATHOF=$(dialog --stdout \
#--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
#TODO! - patch "bashrc" accordingly
#--inputbox 'Choose the install path: < default: ~/OpenFOAM >' 0 0)
# 

#Logging option Dialog
LOG_OUTPUTS=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
--menu 'Do you want to save a log of the script? < default: Yes >' 0 40 0 \
'Yes'   '' \
'No' '' )

#Installation mode dialog
INSTALLMODE=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"    \
--radiolist 'Choose the Install Mode: < default: fresh >' 0 0 0 \
'fresh' 'Make new Install' on  \
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
  LOG_OUTPUTS_FILE_LOCATION=$PWD/installOF.log
fi

#Mirror selection dialog
mirror=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
--menu 'Choose your location for mirror selection? < default: autodetect >' 0 40 0 \
findClosest 'Autodetect closest' \
optusnet 'Australia' \
ufpr 'Brazil' \
nchc 'China/Taiwan' \
mesh 'Germany' \
garr 'Italy' \
jaist 'Japan' \
puzzle 'Switzerland' \
kent 'UK' \
internap 'US' )

#Detect and take care of fastest mirror
if [ "$mirror" == "findClosest" ]; then
  (echo "Searching for the closest mirror..."
    echo "It can take from 10s to 90s (estimated)..."
    echo "--------------------"
    echo "It can provide fake closest!"
    echo "--------------------"
    best_time=9999
    #predefine value to mesh, otherwise it will be stuck in an endless loop!
    mirrorf=mesh
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
  rm -f tempmirror.log
fi
clear

#Show to user the detected settings, last chance to cancel the installer
dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
--title "Final settings - <ESC> to abort the Installer" \
--msgbox "-------------------------------------------------------------------------\n
| =========   Detected that you are running: Ubuntu $version - $arch\n
| \\      /    The choosed mirror is: $mirror\n
|  \\    /     Loging: $LOG_OUTPUTS\n
|   \\  /      Install mode: $INSTALLMODE\n
|    \\/       Run apt-get upgrade ? $DOUPGRADE\n
|             Fix tutorials ? $FIXTUTORIALS\n
| *installOF* Build documentation ? $BUILD_DOCUMENTATION <nothing means no>\n
| *settings*  Use startFoam alias ? $USE_ALIAS_FOR_BASHRC\n
|             Use OpenFOAM gcc ? $USE_OF_GCC\n
-------------------------------------------------------------------------\n
!For more info see documentation on code.google.com/p/openfoam-ubuntu" 16 80
clear

#END OF INTERACTIVE SECTION  ----------------------------------

#Run usual install steps if in "fresh" or "server" install mode
#If not, skip to the last few lines of the script
if [ "$INSTALLMODE" != "update" ]; then

  #Defining packages to download
  define_packages_to_download

  #install packages in Ubuntu
  install_ubuntu_packages

  #Create OpenFOAM folder in $PATHOF dir
  create_OpenFOAM_folder

  #Download necessary files
  download_files
  
  #Unpack downloaded files
  unpack_downloaded_files

  #git clone OpenFOAM
  OpenFOAM_git_clone

  #apply patches and fixes
  apply_patches_fixes

  #Activate OpenFOAM environment
  setOpenFOAMEnv

  #Add OpenFOAM's bashrc entry in $PATHOF/.bashrc
  add_openfoam_to_bashrc

  #fix the tutorials (checking if user option is done in function as well)
  # NOTE: do this before building gcc and running Allwmake, because at least 
  #      this shouldn't fail... or at least we don't check it
  fix_tutorials

  #TODO: build gcc here. NOTE: it should check itself if failed to build!
  #TODO: if gcc fails to build, stop installation, because all of the remaining steps will need this gcc version!

  #do an Allwmake on OpenFOAM 1.6.x
  allwmake_openfoam

  #check if the installation is complete
  check_installation

  #Continue with the next steps, only if it's OK to continue!
  if [ x"$FOAMINSTALLFAILED" == "x" -o x"$FOAMINSTALLFAILED_BUTCONT" == "xYes" ]; then

    #TODO: build Qt here
    
    #TODO: build Paraview
    #TODO: build the PV3FoamReader plugin
    
    #TODO: build ccm26ToFoam
    
  fi

  #final messages and instructions
  final_messages_for_clean_install

fi

#TODO! Create missing update routines (if any missing), and add option to dialog interface
if [ "$INSTALLMODE" == "update" ]; then

  #Activate OpenFOAM environment
  setOpenFOAMEnv

  #do a git pull
  OpenFOAM_git_pull

  #do an Allwmake on OpenFOAM 1.6.x
  allwmake_openfoam

fi

set +e

if [ x"$FOAMINSTALLFAILED" == "x" -o x"$FOAMINSTALLFAILED_BUTCONT" == "xYes" ]; then
  # NOTE: run bash instead of exit, so the OpenFOAM environment stays operational on 
  #the calling terminal.
  bash
else
  #this shouldn't be necessary, but just in case:
  exit
fi
