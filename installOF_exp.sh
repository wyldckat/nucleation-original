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
#TODO 1 - Test building Qt, Paraview, PV3FoamReader and gcc

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
  set +e
  DPKGRESULTTMP=`dpkg-query -W -f='${Status}\n' $1 2>&1 | grep -e "not-installed" -e "No packages found"`
  if [ "x$DPKGRESULTTMP" == "x" ]; then
    return 1
  else
    return 0
  fi
  unset DPKGRESULTTMP
  set -e
}

#is sh->bash ? if so, returns 1, else 0
function is_sh_bash()
{
  set +e
  if [ "x`find \`which sh\` -lname bash`" == "x" ]; then
    return 0
  else
    return 1
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

#set LC_ALL to C
function set_system_to_neutral_lang()
{
  export LC_ALL=C
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
  cd "$PATHOF"
}

function monitor_sleep()
{
  count_secs=0
  while ps -p $1 > /dev/null; do
    sleep 1
    count_secs=`expr $count_secs + 1`
    if [ "$count_secs" == "$2" ]; then
      break;
    fi
  done
}
#-- END UTILITY FUNCTIONS --------------------------------------------------

#-- PATCHING FUNCTIONS -----------------------------------------------------

#patch bashrc path so it will reflect the chosen $PATHOF
function patchBashrcPath()
{
tmpVar=$PWD
cd_openfoam
cd OpenFOAM-1.6.x/etc/

echo '--- ../bashrc 2010-05-02 13:08:09.905803554 +0200
+++ bashrc  2010-05-02 13:18:36.991912551 +0200
@@ -43,7 +43,8 @@
 #
 # Location of FOAM installation
 # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-foamInstall=$HOME/$WM_PROJECT
+foamInstall='$PATHOF'
+# foamInstall=$HOME/$WM_PROJECT
 # foamInstall=~$WM_PROJECT
 # foamInstall=/usr/local/$WM_PROJECT
 # foamInstall=/opt/$WM_PROJECT
@@ -68,7 +69,7 @@
 # ~~~~~~~~~~~~~~~~~~~~~~~~~~~
 export WM_PROJECT_INST_DIR=$FOAM_INST_DIR
 export WM_PROJECT_DIR=$WM_PROJECT_INST_DIR/$WM_PROJECT-$WM_PROJECT_VERSION
-export WM_PROJECT_USER_DIR=$HOME/$WM_PROJECT/$USER-$WM_PROJECT_VERSION
+export WM_PROJECT_USER_DIR=$FOAM_INST_DIR/$USER-$WM_PROJECT_VERSION
 
 
 # Location of third-party software' | patch -p0

cd $tmpVar
unset tmpVar
}

#Patch to compile using multicore
function patchBashrcMultiCore()
{
tmpVar=$PWD
cd_openfoam
cd OpenFOAM-1.6.x/etc/

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
cd_openfoam
cd OpenFOAM-1.6.x/etc/

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
cd_openfoam
cd OpenFOAM-1.6.x/etc/

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
cd_openfoam
cd OpenFOAM-1.6.x/bin/

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


#Patch AllwmakeLibccmio script
#Code source for patch: http://www.cfd-online.com/Forums/openfoam-bugs/62300-of15-libccmio-thus-ccm26tofoam-do-not-compile-2.html
function patchAllwmakeLibccmioScript()
{
tmpVar=$PWD
cd_openfoam
cd ThirdParty-1.6/

echo '--- ../AllwmakeLibccmio  2009-07-24 13:51:14.000000000 +0100
+++ AllwmakeLibccmio 2009-10-17 11:29:36.000000000 +0100
@@ -33,6 +33,7 @@
 set -x
 
 packageDir=libccmio-2.6.1
+origDir=$PWD
 
 if [ ! -d ${packageDir} ]
 then
@@ -52,7 +53,17 @@
 
 if [ -d ${packageDir} -a ! -d ${packageDir}/Make ]
 then
-   cp -r wmakeFiles/libccmio/Make ${packageDir}/Make
+  if [ ! -d "wmakeFiles/libccmio/Make" ]; then
+    mkdir -p ${packageDir}/Make
+    cd ${packageDir}/Make
+    wget http://www.cfd-online.com/OpenFOAM_Discus/messages/126/files-8822.unk
+    wget http://www.cfd-online.com/OpenFOAM_Discus/messages/126/options-8823.unk
+    mv -i files-8822.unk files
+    mv -i options-8823.unk options
+    cd $origDir
+  else
+    cp -r wmakeFiles/libccmio/Make ${packageDir}/Make
+  fi
 fi
 
 if [ -d ${packageDir}/Make ]' | patch -p0
cd $tmpVar
unset tmpVar
}

#Patch the missing files in MPFR that comes with the ThirdParty.General package
function patchMPFRMissingFiles()
{
tmpVar=$PWD
cd_openfoam
cd ThirdParty-1.6/

if [ -e "$PATHOF/$MPFRPATCHFILE" ]; then
  patch -p1 < $PATHOF/$MPFRPATCHFILE
fi

cd $tmpVar
unset tmpVar
}

#patch makeParaView script to allow -noqt option
function patchMakeParaViewScript()
{
tmpVar=$PWD
cd_openfoam
cd ThirdParty-1.6/
  
echo '--- ../makeParaView  2010-04-18 21:49:00.611392700 +0100
+++ ./makeParaView  2010-04-18 21:50:31.609831213 +0100
@@ -75,6 +75,7 @@
   -python       with python (if not already enabled)
   -mesa         with mesa (if not already enabled)
   -qt           with extra Qt gui support (if not already enabled)
+  -noqt         without extra Qt gui support (if not already disabled)
   -verbose      verbose output in Makefiles
   -version VER  specify an alternative version (default: $ParaView_VERSION)
   -help
@@ -104,6 +105,7 @@
 case "$Script" in *-python*) withPYTHON=true;; esac
 case "$Script" in *-mesa*)   withMESA=true;; esac
 case "$Script" in *-qt*)     withQTSUPPORT=true;; esac
+case "$Script" in *-noqt*)     withQTSUPPORT=false;; esac
 
 #
 # various building stages
@@ -181,6 +183,10 @@
         withQTSUPPORT=true
         shift
         ;;
+    -noqt)
+        withQTSUPPORT=false
+        shift
+        ;;
     -qmake)
         [ "$#" -ge 2 ] || usage "'$1' option requires an argument"
         export QMAKE_PATH=$2' | patch -p0
cd $tmpVar
unset tmpVar
}

#patch makeQt script to allow one more option for building Qt
function patchMakeQtScript()
{
tmpVar=$PWD
cd_openfoam
cd ThirdParty-1.6/
  
echo '--- ../makeQt 2010-04-26 23:10:03.000000000 +0100
+++ makeQt  2010-04-26 23:11:10.000000000 +0100
@@ -45,7 +45,7 @@
     ./configure \
         --prefix=${QT_ARCH_PATH} \
         -nomake demos \
-        -nomake examples
+        -nomake examples $1
 
     if [ -r /proc/cpuinfo ]
     then' | patch -p0

cd $tmpVar
unset tmpVar
}

#Patch wmake to provide timings upon request via WM_DO_TIMINGS
function patchWmakeForTimings()
{
tmpVar=$PWD
cd_openfoam
cd OpenFOAM-1.6.x/wmake/

patch -p0 < "$PATHOF/$WMAKEPATCHFILE"

cd $tmpVar
unset tmpVar
}

#-- END PATCHING FUNCTIONS -------------------------------------------------

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
    yes | y | Y | Yes | YES) SHOW_SUDO_COMMANDS_ONLY="";;
    no | n | N | No | NO) SHOW_SUDO_COMMANDS_ONLY="YES";;
  esac
  echo "------------------------------------------------------"
}

#install dialog or abort if not possible
function install_dialog_package()
{
  ispackage_installed dialog
  if [ "x$?" == "x0" ]; then
    #if permission granted
    if [ "x$SHOW_SUDO_COMMANDS_ONLY" != "xYES" ]; then
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

  #confirm it's installed
  ispackage_installed dialog
  if [ "x$?" == "x0" ]; then
    echo "The package dialog isn't installed. Aborting script."
    exit 1
  fi
}

#Defining packages and servers to download from
function define_packages_to_download()
{
  #This script's repository
  OPENFOAM_UBUNTU_SCRIPT_REPO="http://openfoam-ubuntu.googlecode.com/hg/"
  
  #OpenFOAM's sourceforge repository
  OPENFOAM_SOURCEFORGE="http://downloads.sourceforge.net/foam/"
  SOURCEFORGE_URL_OPTIONS="?use_mirror=$mirror"
  
  #Third Party files to download
  THIRDPARTY_GENERAL="ThirdParty-1.6.General.gtgz"
  if [ "$arch" == "x86_64" ]; then
    THIRDPARTY_BIN="ThirdParty-1.6.linux64Gcc.gtgz"
    
    isleftlarger_or_equal 8.04 $version
    if [ x"$?" == x"1" ]; then
      THIRDPARTY_BIN_CMAKE="ThirdParty-1.6.linuxGcc.gtgz"
    fi
  elif [ x`echo $arch | grep -e "i.86"` != "x" ]; then
    THIRDPARTY_BIN="ThirdParty-1.6.linuxGcc.gtgz"
  else
    echo "Sorry, architecture not recognized, aborting."
    exit 1
  fi
  
  #patch file for MPFR for gcc 4.3.3 to build properly
  MPFRPATCHFILE="patchMPFR"
  
  #modified makeGcc for building gcc that comes with OpenFOAM
  GCCMODED_MAKESCRIPT="makeGcc433"
  
  #patch file for tweaking timing option into wmake
  WMAKEPATCHFILE="patchWmake"
  
  if [ "$BUILD_QT" == "Yes" ]; then
    QT_VERSION=4.3.5
    QT_BASEURL="ftp://ftp.trolltech.com/qt/source/"
    QT_PACKAGEFILE="qt-x11-opensource-src-$QT_VERSION.tar.bz2"
  fi
  
  if [ "x$BUILD_CCM26TOFOAM" == "xYes" ]; then
    CCMIO_PACKAGE_VERSION=libccmio-2.6.1
    CCMIO_PACKAGE="${CCMIO_PACKAGE_VERSION}.tar.gz"
    CCMIO_BASEURL="https://wci.llnl.gov/codes/visit/3rd_party/"
    CCMIO_BASEURL_EXTRA_PRE="--no-check-certificate"
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
  
  #for Ubuntu 10.04, a few more packages are needed
  isleftlarger_or_equal $version 10.04
  if [ x"$?" == x"1" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL libxt-dev"
  fi

  #for documentation, these are necessary
  if [ "$BUILD_DOCUMENTATION" == "doc" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL doxygen graphviz"
  fi

  #for building gcc, these are necessary
  if [ "x$BUILD_GCC" == "xYes" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL texinfo byacc bison"
  fi
  
  #now remove the ones that are already installed
  prune_packages_to_install
  
  #only show commands for installation if any packages are missing!
  if [ x"$PACKAGES_TO_INSTALL" != "x" ]; then

    #if permission granted
    if [ x"$SHOW_SUDO_COMMANDS_ONLY" != "xYES" ]; then

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

# the 1st argument is the base address
# the 2nd argument is the file name
# the 3rd argument is the rest of the URL address
# the 4th argument is additional arguments to be given to wget before the URL
function do_wget()
{
  #either get the whole file, or try completing it, in case the user 
  #used previously Ctrl+C
  if [ ! -e "$2" ]; then
    wget "$4" "$1""$2""$3" 2>&1
  else
    wget -c "$4" "$1""$2""$3" 2>&1
  fi
}

#Download necessary files
function download_files()
{
  cd_openfoam #this is a precautionary measure

  #Download Third Party files for detected system and selected mirror
  #download Third Party sources
  do_wget "$OPENFOAM_SOURCEFORGE" "$THIRDPARTY_GENERAL" "$SOURCEFORGE_URL_OPTIONS"

  #download Third Party binaries, but only if requested and necessary!
  if [ "x$THIRDPARTY_BIN" != "x" ]; then
      do_wget "$OPENFOAM_SOURCEFORGE" "$THIRDPARTY_BIN" "$SOURCEFORGE_URL_OPTIONS"
  fi
  
  if [ "x$THIRDPARTY_BIN_CMAKE" != "x" ]; then
      do_wget "$OPENFOAM_SOURCEFORGE" "$THIRDPARTY_BIN_CMAKE" "$SOURCEFORGE_URL_OPTIONS"
  fi

  #TODO: md5sum check?

  #download patch files that didn't fit in this script
  do_wget "$OPENFOAM_UBUNTU_SCRIPT_REPO" "$MPFRPATCHFILE"
  do_wget "$OPENFOAM_UBUNTU_SCRIPT_REPO" "$GCCMODED_MAKESCRIPT"
  do_wget "$OPENFOAM_UBUNTU_SCRIPT_REPO" "$WMAKEPATCHFILE"

  if [ "$BUILD_QT" == "Yes" ]; then
    do_wget "$QT_BASEURL" "$QT_PACKAGEFILE"
  fi

  if [ "x$BUILD_CCM26TOFOAM" == "xYes" ]; then
    do_wget "$CCMIO_BASEURL" "$CCMIO_PACKAGE" " " "$CCMIO_BASEURL_EXTRA_PRE"
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
  
  #needed for Ubuntu 8.04 x86_64
  if [ "x$THIRDPARTY_BIN_CMAKE" != "x" ]; then 
    tar xfz $THIRDPARTY_BIN_CMAKE ThirdParty-1.6/cmake-2.6.4
  fi
  
  if [ "$BUILD_QT" == "Yes" ]; then
    cd ThirdParty-1.6
    tar xjf ../$QT_PACKAGEFILE
  fi

  #copy modified makeGcc to here
  if [ "x$GCCMODED_MAKESCRIPT" != "x" ]; then
    cd_openfoam
    cd ThirdParty-1.6
    cp ../$GCCMODED_MAKESCRIPT .
    chmod +x $GCCMODED_MAKESCRIPT
  fi
  echo "------------------------------------------------------"
}

function process_online_log_of_timings()
{
  #TODO: this value is hard coded for now, since it should come from the output of our timmings script
  #The total count of "make[.]" found in our build_Qt_log
  BUILD_QT_LAST_BUILD_COUNT=293
}

#git clone OpenFOAM
function OpenFOAM_git_clone()
{
  cd_openfoam #this is a precautionary measure

  echo "------------------------------------------------------"
  echo "Retrieving OpenFOAM 1.6.x from git..."
  echo "------------------------------------------------------"
  #redo the link if necessary
  if [ -L "$PATHOF/ThirdParty-1.6.x" ]; then
    unlink $PATHOF/ThirdParty-1.6.x
  fi
  ln -s $PATHOF/ThirdParty-1.6 $PATHOF/ThirdParty-1.6.x
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
  if [ "x$HOME/OpenFOAM" != "x$PATHOF" ]; then #fix OpenFOAM base path in bashrc
    patchBashrcPath
  fi
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
  
  #apply patches for wmake script, MPFR library, makeQt script, makeParaView script and libccmio
  patchWmakeForTimings
  patchMPFRMissingFiles
  patchMakeQtScript
  patchMakeParaViewScript
  patchAllwmakeLibccmioScript
}

#Activate OpenFOAM environment
function setOpenFOAMEnv()
{
  echo "------------------------------------------------------"
  echo "Activate OpenFOAM environment"
  echo "------------------------------------------------------"
  cd OpenFOAM-1.6.x/
  . $PATHOF/OpenFOAM-1.6.x/etc/bashrc 
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
    echo -e "alias startFoam=\". $PATHOF/OpenFOAM-1.6.x/etc/bashrc\"" >> ~/.bashrc
  else
    echo ". $PATHOF/OpenFOAM-1.6.x/etc/bashrc" >> ~/.bashrc
  fi
}

#build gcc that comes with OpenFOAM
function build_openfoam_gcc()
{
  if [ "x$BUILD_GCC" == "xYes" ]; then
    
    #set up environment, just in case we forget about it!
    if [ x"$WM_PROJECT_DIR" == "x" ]; then
      setOpenFOAMEnv
    fi

    cd $WM_THIRD_PARTY_DIR

    BUILD_GCC_ROOT="$WM_THIRD_PARTY_DIR/gcc-4.3.3/platforms/$WM_ARCH$WM_COMPILER_ARCH"
    #purge existing gcc
    if [ -e "$BUILD_GCC_ROOT" ]; then
      rm -rf $BUILD_GCC_ROOT
    fi 

    if [ "x$BUILD_GCC_STRICT_64BIT" == "xYes" ]; then
      BUILD_GCC_OPTION="--disable-multilib"
    fi
    
    BUILD_GCC_LOG="$WM_THIRD_PARTY_DIR/build_gcc.log"
    
    echo "------------------------------------------------------"
    echo "Build gcc-4.3.3:"
    echo "The build process is going to be logged in the file:"
    echo "  $BUILD_GCC_LOG"
    echo "If you want to, you can follow the progress of this build"
    echo "process, by opening a new terminal and running:"
    echo "  tail -F $BUILD_GCC_LOG"
    echo "Either way, please wait, this will take a while..."
    bash -c "time ./$GCCMODED_MAKESCRIPT $BUILD_GCC_OPTION" > "$BUILD_GCC_LOG" 2>&1

    if [ -e "$BUILD_GCC_ROOT/bin/gcc" ]; then
      echo "Build process finished successfully: gcc is ready to be used."
    else
      echo "Build process didn't finished with success. Please check the log file for more information."
      echo "You can post it at this forum thread:"
      echo "  http://www.cfd-online.com/Forums/openfoam-installation/73805-openfoam-1-6-x-installer-ubuntu.html"
      echo -e '\nYou can also verify that thread for other people who might have had the same problems.'
      BUILD_GCC_FAILED="Yes"
    fi
    echo "------------------------------------------------------"
    
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
  export WM_DO_TIMINGS="Yes"
  bash -c "time wmake all $BUILD_DOCUMENTATION > make.log 2>&1" 2>&1
  export WM_DO_TIMINGS=
  #bash -c is the only way I got for getting time results straight to display and also logged
  echo "Build complete at: `date`"
}

function continue_after_failed_openfoam()
{
  if [ x"$FOAMINSTALLFAILED" != "x" ]; then
    FOAMINSTALLFAILED_BUTCONT="No"
    echo "Although the previous step seems to have failed, do you wish to continue with the remaining steps?"
    
    if [ "$BUILD_CCM26TOFOAM" == "Yes" -o "$BUILD_PARAVIEW" == "Yes" -o "$BUILD_QT" == "Yes" ]; then 
      echo "Missing steps are:"
      if [ "$BUILD_QT" == "Yes" ]; then echo "- Building Qt"; fi
      if [ "$BUILD_PARAVIEW" == "Yes" ]; then echo "- Building Paraview"; fi
      if [ "$BUILD_CCM26TOFOAM" == "Yes" ]; then echo "- Building ccm26ToFoam"; fi
    fi

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
  IFERRORSDETECTED=`cat foamIT.log | grep "Critical systems ok"`
  if [ "x$IFERRORSDETECTED" == "x" ]; then
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
  unset IFERRORSDETECTED
}

function fix_tutorials()
{
  #fix tutorials, if sh isn't linked to bash
  is_sh_bash
  if [ "x$?" == "x0" ]; then
    #set up environment, just in case we forget about it!
    if [ x"$FOAM_TUTORIALS" == "x" ]; then
      setOpenFOAMEnv
    fi

    cd $WM_PROJECT_DIR

    echo "------------------------------------------------------"
    echo "Fixing call for bash in tutorials (default is dash in Ubuntu)"
    #NOTE: searching for patterns requires quotes
    find $FOAM_TUTORIALS/ -name "All*" | \
    while read file
    do
        mv "$file" "$file.old"
        sed '/^#!/ s/\/bin\/sh/\/bin\/bash/' "$file.old" > "$file"
        rm -f "$file.old"
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

#provide the user with a progress bar and timings for building Qt
function build_Qt_progress_dialog()
{
  ( #while true is used as a containment cycle...
  while true;
  do
    if [ "x$BUILD_QT_MUST_KILL" == "xYes" ]; then
      echo $percent
      echo "XXX"
      echo -e "\n\nKill code issued... please wait..."
      echo "XXX"
      kill $BUILD_QT_PID
      sleep 1
      if ps -p $BUILD_QT_PID > /dev/null; then
        break;
      fi
    else
      BUILD_QT_MAKECOUNT=`grep 'make\[.\]' build_Qt.log | wc -l`
      nowpercent=`expr $BUILD_QT_MAKECOUNT \* 100 / $BUILD_QT_LAST_BUILD_COUNT`
      if [ "$nowpercent" != "$percent" ]; then
        percent=$nowpercent
        BUILD_QT_UPDATE_TIME=`date`
      fi
      echo $percent
      echo "XXX"
      echo "Build Qt ${QT_VERSION}:"
      echo "The build process is going to be logged in the file:"
      echo "  $BUILD_QT_LOG"
      echo "If you want to, you can follow the progress of this build"
      echo "process, by opening a new terminal and running:"
      echo "  tail -F $BUILD_QT_LOG"
      echo "Either way, please wait, this will take a while..."
      echo -e "Qt started to build at:\n\t$BUILD_QT_START_TIME\n"
      echo -e "Last progress update made at:\n\t$BUILD_QT_UPDATE_TIME"
      echo "XXX"
    fi

    #this provides a better monitorization of the process itself... i.e., if it has already stopped!
    #30 second update
    monitor_sleep $BUILD_QT_PID 30

    if ! ps -p $BUILD_QT_PID > /dev/null; then
      break;
    fi
  done
  ) | dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
      --title "Building Qt" --gauge "Starting..." 15 60 $percent
}

#this indicates to the user that we have it under control...
function build_Qt_ctrl_c_triggered()
{
  BUILD_QT_MUST_KILL="Yes"
  build_Qt_progress_dialog
}

function build_Qt()
{
  if [ "$BUILD_QT" == "Yes" ]; then
    #set up environment, just in case we forget about it!
    if [ x"$WM_PROJECT_DIR" == "x" ]; then
      setOpenFOAMEnv
    fi

    cd $WM_THIRD_PARTY_DIR
    
    QT_PLATFORM_PATH="${WM_THIRD_PARTY_DIR}/qt-x11-opensource-src-${QT_VERSION}/platforms/${WM_OPTIONS}"
    #purge existing Qt
    if [ -e "$QT_PLATFORM_PATH" ]; then
      rm -rf $QT_PLATFORM_PATH
    fi 
    
    BUILD_QT_LOG="$WM_THIRD_PARTY_DIR/build_Qt.log"
    
    #set up traps...
    trap build_Qt_ctrl_c_triggered SIGINT SIGQUIT SIGTERM

    #launch makeQt asynchronously
    bash -c "time ./makeQt --confirm-license=yes" > "$BUILD_QT_LOG" 2>&1 &
    BUILD_QT_PID=$!
    BUILD_QT_START_TIME=`date`
    BUILD_QT_UPDATE_TIME=$BUILD_QT_START_TIME

    #track build progress
    percent=0
    build_Qt_progress_dialog

    #clear traps
    trap - SIGINT SIGQUIT SIGTERM
    
    clear
    echo "------------------------------------------------------"
    echo "Build Qt ${QT_VERSION}:"
    if [ -e "$QT_PLATFORM_PATH/bin/qmake" ]; then
      echo -e "Qt started to build at:\n\t$BUILD_QT_START_TIME\n"
      echo -e "Building Qt finished successfully at:\n\t`date`"
      echo "Qt is ready to use for building Paraview."
    else
      echo "Build process didn't finished with success. Please check the log file for more information."
      echo "You can post it at this forum thread:"
      echo "  http://www.cfd-online.com/Forums/openfoam-installation/73805-openfoam-1-6-x-installer-ubuntu.html"
      echo -e '\nYou can also verify that thread for other people who might have had the same problems.'
      BUILDING_QT_FAILED="Yes"
    fi
    echo "------------------------------------------------------"

  fi
}

function build_Paraview()
{
  if [ "$BUILD_PARAVIEW" == "Yes" ]; then
    
    if [ "$BUILD_QT" == "Yes" -a "x$BUILDING_QT_FAILED" == "xYes" ]; then

      echo "------------------------------------------------------"
      echo "The requested Qt is unavailable, thus rendering impossible to build Paraview with it."
      echo "------------------------------------------------------"

    else

      #set up environment, just in case we forget about it!
      if [ x"$WM_PROJECT_DIR" == "x" ]; then
        setOpenFOAMEnv
      fi

      cd $WM_THIRD_PARTY_DIR

      #purge existing Paraview
      if [ -e "$ParaView_DIR" ]; then
        rm -rf $ParaView_DIR
      fi 

      PARAVIEW_BUILD_OPTIONS=""
      if [ "$BUILD_QT" == "Yes" ]; then
        PARAVIEW_BUILD_OPTIONS="$PARAVIEW_BUILD_OPTIONS -qmake \"$QT_PLATFORM_PATH/bin/qmake\""
      fi

      if [ "$BUILD_PARAVIEW_WITH_GUI" == "No" ]; then
        PARAVIEW_BUILD_OPTIONS="$PARAVIEW_BUILD_OPTIONS -noqt"
      fi

      if [ "$BUILD_PARAVIEW_WITH_MPI" == "Yes" ]; then
        PARAVIEW_BUILD_OPTIONS="$PARAVIEW_BUILD_OPTIONS -mpi"
      fi

      if [ "$BUILD_PARAVIEW_WITH_PYTHON" == "Yes" ]; then
        PARAVIEW_BUILD_OPTIONS="$PARAVIEW_BUILD_OPTIONS -python"
      fi

      PARAVIEW_BUILD_LOG="$WM_THIRD_PARTY_DIR/build_Paraview.log"
      echo "------------------------------------------------------"
      echo "Build Paraview:"
      echo "The build process is going to be logged in the file:"
      echo "  $PARAVIEW_BUILD_LOG"
      echo "If you want to, you can follow the progress of this build"
      echo "process, by opening a new terminal and running:"
      echo "  tail -F $PARAVIEW_BUILD_LOG"
      echo "Either way, please wait, this will take a while..."
      bash -c "time ./makeParaView $PARAVIEW_BUILD_OPTIONS" > "$PARAVIEW_BUILD_LOG" 2>&1

      #TODO: commented line code is for later using in a gauge dialog for monitoring Paraview build process
      #TODO: will have to use & with bash and then use BUILD_PARAVIEW_PID=$!
      #TODO: also use trap "command" SIGINT SIGTERM or just INT for trapping Ctrl+C and doing a "remote" killing of the launched bash.
      #TODO: use trap without command and with sig's to disable the set traps!
      #TODO: and don't forget to monitor if it's still running to terminate while loop!
      # tail -n 1 "$PARAVIEW_BUILD_LOG" | grep "^\[" | sed 's/^\[\([ 0-9]*\).*/\1/'

      if [ -e "$ParaView_DIR/bin/paraview" ]; then
        echo "Build process finished successfully: Paraview is ready to use."
      else
        echo "Build process didn't finished with success. Please check the log file for more information."
        echo "You can post it at this forum thread:"
        echo "  http://www.cfd-online.com/Forums/openfoam-installation/73805-openfoam-1-6-x-installer-ubuntu.html"
        echo -e '\nYou can also verify that thread for other people who might have had the same problems.'
        BUILDING_PARAVIEW_FAILED="Yes"
        #TODO: do something with BUILDING_PARAVIEW_FAILED
      fi
      echo "------------------------------------------------------"

    fi
  fi
}

function build_PV3FoamReader()
{
  if [ "$BUILD_PARAVIEW" == "Yes" ]; then
    
    #set up environment, just in case we forget about it!
    if [ x"$WM_PROJECT_DIR" == "x" ]; then
      setOpenFOAMEnv
    fi

    if [ "$BUILD_QT" == "Yes" -a "x$BUILDING_QT_FAILED" == "xYes" ]; then

      echo "------------------------------------------------------"
      echo "No Qt, no Paraview, thus no PV3FoamReader."
      echo "------------------------------------------------------"

    elif [ ! -e "$ParaView_DIR/bin/paraview" ]; then
      
      echo "------------------------------------------------------"
      echo "Paraview isn't available where it is expected:"
      echo "  $ParaView_DIR/bin/paraview"
      echo "Therefore it isn't possible to proceed with building the plugin PV3FoamReader."
      echo "------------------------------------------------------"
      
    else

      cd "$FOAM_UTILITIES/postProcessing/graphics/PV3FoamReader"
      
      PV3FOAMREADER_BUILD_LOG="$WM_PROJECT_DIR/build_PV3FoamReader.log"

      echo "------------------------------------------------------"
      echo "Build PV3FoamReader for Paraview:"
      echo "The build process is going to be logged in the file:"
      echo "  $PV3FOAMREADER_BUILD_LOG"
      echo "If you want to, you can follow the progress of this build"
      echo "process, by opening a new terminal and running:"
      echo "  tail -F $PV3FOAMREADER_BUILD_LOG"
      echo "Either way, please wait, this will take a while..."

      bash -c "time ./Allwclean" > "$PV3FOAMREADER_BUILD_LOG" 2>&1
      echo -e "\n\n" >> "$PV3FOAMREADER_BUILD_LOG"
      export WM_DO_TIMINGS="Yes"
      bash -c "time wmake all" >> "$PV3FOAMREADER_BUILD_LOG" 2>&1
      export WM_DO_TIMINGS=

      if [ -e "$FOAM_LIBBIN/libvtkPV3Foam.so" -a -e "$FOAM_LIBBIN/libPV3FoamReader.so" -a -e "$FOAM_LIBBIN/libPV3FoamReader_SM.so" ]; then
        echo "Build process finished successfully: paraFoam is ready to use."
      else
        echo "Build process didn't finished with success. Please check the log file for more information."
        echo "You can post it at this forum thread:"
        echo "  http://www.cfd-online.com/Forums/openfoam-installation/73805-openfoam-1-6-x-installer-ubuntu.html"
        echo -e '\nYou can also verify that thread for other people who might have had the same problems.'
        PV3FOAMREADERFAILED="Yes"
        #TODO: do something with PV3FOAMREADERFAILED
      fi
      echo "------------------------------------------------------"
    fi
  fi
}

function build_ccm26ToFoam()
{
  
  if [ "$BUILD_CCM26TOFOAM" == "Yes" ]; then
    #set up environment, just in case we forget about it!
    if [ x"$WM_PROJECT_DIR" == "x" ]; then
      setOpenFOAMEnv
    fi

    cd "$FOAM_APP/utilities/mesh/conversion/Optional/"

    BUILD_CCM26TOFOAM_LOG="$WM_PROJECT_DIR/build_ccm26.log"

    echo "------------------------------------------------------"
    echo "Build ccm26ToFoam:"
    echo "This will also build the libccmio library, which requires "
    echo "specify downloading of the files for it."
    echo "The build process is going to be logged in the file:"
    echo "  $BUILD_CCM26TOFOAM_LOG"
    echo "If you want to, you can follow the progress of this build"
    echo "process, by opening a new terminal and running:"
    echo "  tail -F $BUILD_CCM26TOFOAM_LOG"
    echo "Either way, please wait, this will take a while..."

    export WM_DO_TIMINGS="Yes"
    bash -c "time wmake all" > "$BUILD_CCM26TOFOAM_LOG" 2>&1
    export WM_DO_TIMINGS=

    if [ -e "$FOAM_APPBIN/ccm26ToFoam" ]; then
      echo "Build process finished successfully: ccm26ToFoam is ready to use."
    else
      echo "Build process didn't finished with success. Please check the log file for more information."
      echo "You can post it at this forum thread:"
      echo "  http://www.cfd-online.com/Forums/openfoam-installation/73805-openfoam-1-6-x-installer-ubuntu.html"
      echo -e '\nYou can also verify that thread for other people who might have had the same problems.'
      CCM26INSTALLFAILED="Yes"
      #TODO: do something with CCM26INSTALLFAILED
    fi
    echo "------------------------------------------------------"
  fi
}
#-- END MAIN FUNCTIONS -----------------------------------------------------

#END FUNCTIONS SECTION -----------------------------------------------------

#verify system's language and set to C if not english
issystem_english
if [ x"$?" == "x0" ]; then
  set_system_to_neutral_lang
fi

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
|                        | Based on original work from Mads Reck\n
-----------------------------------------------------------------------" 12 80

#Choose path to install OF, default is already set
PATHOF=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
--inputbox 'Choose the install path: < default: ~/OpenFOAM >' 8 60 ~/OpenFOAM ) 

#Logging option Dialog
LOG_OUTPUTS=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
--menu 'Do you want to save a log of the script? < default: Yes >' 0 40 0 \
'Yes'   '' \
'No' '' )

#Installation mode dialog
INSTALLMODE=$(dialog --stdout \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"    \
--radiolist 'Choose the Install Mode: < default: fresh >' 10 50 3 \
'fresh' 'Make new Install' on  \
'update'   'Update currenty install'           off \
'server'    'Paraview with: -GUI +MPI'    off )

#Settings choosing Dialog
SETTINGSOPTS=$(dialog --stdout --separate-output \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
--checklist "Choose Install settings: < Space to select ! >" 15 50 5 \
1 "Do apt-get upgrade" off \
2 "Build OpenFOAM docs" off \
3 "Use startFoam alias" on \
4 "Use OpenFOAM gcc compiler" on \
5 "Build ccm26ToFoam" off )

#Take care of unpack settings from SETTINGSOPTS
DOUPGRADE=No ; BUILD_DOCUMENTATION=
USE_ALIAS_FOR_BASHRC=No ; USE_OF_GCC=No
BUILD_CCM26TOFOAM=No
for setting in $SETTINGSOPTS ; do
  if [ $setting == 1 ] ; then DOUPGRADE=Yes ; fi
  if [ $setting == 2 ] ; then BUILD_DOCUMENTATION=doc ; fi
  if [ $setting == 3 ] ; then USE_ALIAS_FOR_BASHRC=Yes ; fi
  if [ $setting == 4 ] ; then USE_OF_GCC=Yes ; fi
  if [ $setting == 5 ] ; then BUILD_CCM26TOFOAM=Yes ; fi
done
BUILD_QT=No
BUILD_PARAVIEW=No
BUILD_PARAVIEW_WITH_GUI=No
BUILD_PARAVIEW_WITH_MPI=No
BUILD_PARAVIEW_WITH_PYTHON=No
#ParaView configurations for a fresh install
if [ "$INSTALLMODE" == "fresh" ]; then
    PVSETTINGSOPTS=$(dialog --stdout --separate-output \
--backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
--checklist "Choose ParaView settings: < Space to select ! >" 15 52 5 \
1 "Do custom build of QT 4.3.5 ?" off \
2 "Do custom build of ParaView ?" off \
3 "Build ParaView with GUI ?" on \
4 "Build ParaView with MPI support ?" off \
5 "Build ParaView with Python support ?" off )
fi
#Take care of unpack settings from PVSETTINGSOPTS
for setting in $PVSETTINGSOPTS ; do
  if [ $setting == 1 ] ; then BUILD_QT=Yes ; fi
  if [ $setting == 2 ] ; then BUILD_PARAVIEW=Yes ; fi
  if [ $setting == 3 ] ; then BUILD_PARAVIEW_WITH_GUI=Yes ; fi
  if [ $setting == 4 ] ; then BUILD_PARAVIEW_WITH_MPI=Yes ; fi
  if [ $setting == 5 ] ; then BUILD_PARAVIEW_WITH_PYTHON=Yes ; fi
done

if [ "$version" == "10.04" ]; then
    BUILD_PARAVIEW=Yes
    dialog --sleep 6 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
    --title "Non-optional setting detected!" \
    --infobox "You are running Ubuntu $version. \n To ParaView properly work this script will do a custom build of ParaView and PV3FoamReader" 5 70
fi
if [ "$version" == "8.04" ]; then
    BUILD_QT=Yes
    BUILD_PARAVIEW=Yes
    dialog --sleep 6 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
    --title "Non-optional setting detected!" \
    --infobox "You are running Ubuntu $version. \nFor ParaView to work properly this script must do a custom\nbuild of Qt and also build Paraview." 5 70
fi
if [ "$INSTALLMODE" == "server" ]; then
    BUILD_PARAVIEW=Yes
    BUILD_PARAVIEW_WITH_GUI=No
    BUILD_PARAVIEW_WITH_MPI=Yes
    dialog --sleep 6 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
    --title "Server Install settings" \
    --infobox "Installer in server install mode. \n ParaView will be build without GUI and with MPI support" 5 70  
fi

#verifying Paraview Build options, just in case
if [ "$BUILD_PARAVIEW" == "No" ]; then
  if [ "$BUILD_PARAVIEW_WITH_MPI" == "Yes" -o "$BUILD_PARAVIEW_WITH_PYTHON" == "Yes" -o "$BUILD_PARAVIEW_WITH_GUI" == "No" ]; then
      BUILD_PARAVIEW=Yes
      dialog --sleep 6 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
      --title "Non-optional setting detected!" \
      --infobox "\nParaView will need to be built, since GUI is the pre-built version" 5 70
  fi
fi

#GCC compiling settings
if [ "$USE_OF_GCC" == "Yes" ]; then
  if [ "$arch" == "x86_64" ]; then
    GCCSETTINGSOPTS=$(dialog --stdout --separate-output \
    --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
    --checklist "Choose Install settings: < Space to select ! >" 10 60 2 \
    1 "Build GCC? (otherwise use pre-compiled version)" off \
    2 "Build GCC in 64bit mode only?" off )

  elif [ x`echo $arch | grep -e "i.86"` != "x" ]; then
  
    GCCSETTINGSOPTS=$(dialog --stdout --separate-output \
    --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
    --checklist "Choose Install settings: < Space to select ! >" 10 60 1 \
    1 "Build GCC? (otherwise use pre-compiled version)" off )
  fi

  BUILD_GCC=No
  BUILD_GCC_STRICT_64BIT=No #this is optionable for x86_64 only
  #Take care of unpack
  for setting in $GCCSETTINGSOPTS ; do
    if [ $setting == 1 ] ; then BUILD_GCC=Yes ; fi
    if [ $setting == 2 ] ; then BUILD_GCC_STRICT_64BIT=Yes ; fi
  done
fi

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
  clear

  #show an empty dialog info box, to reduce flickering
  dialog --sleep 0 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
    --title "Mirror selector" \
    --infobox " " 17 50

  (echo "Searching for the closest mirror..."
    echo "It can take from 10s to 90s (estimated)..."
    echo "--------------------"
    echo "Warning: This could provide a fake closest!"
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
|  \\    /     Logging: $LOG_OUTPUTS\n
|   \\  /      Install mode: $INSTALLMODE\n
|    \\/       Run apt-get upgrade ? $DOUPGRADE\n
| *installOF* Build documentation ? $BUILD_DOCUMENTATION <nothing means no>\n
| *settings*  Use startFoam alias ? $USE_ALIAS_FOR_BASHRC\n
|             Use OpenFOAM gcc ? $USE_OF_GCC\n
-------------------------------------------------------------------------\n
!For more info see documentation on code.google.com/p/openfoam-ubuntu" 14 80
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
  
  #process our timming log, in order to provide progress and estimated timings
  process_online_log_of_timings

  #git clone OpenFOAM
  OpenFOAM_git_clone

  #apply patches and fixes
  apply_patches_fixes

  #Activate OpenFOAM environment
  setOpenFOAMEnv

  #Add OpenFOAM's bashrc entry in $PATHOF/.bashrc
  add_openfoam_to_bashrc

  #fix the tutorials (works only after setting the environment)
  fix_tutorials

  #build gcc
  build_openfoam_gcc

  #This part can't go on without gcc...
  if [ "x$BUILD_GCC_FAILED" != "xYes" ]; then

    #do an Allwmake on OpenFOAM 1.6.x
    allwmake_openfoam

    #check if the installation is complete
    check_installation

    #Continue with the next steps, only if it's OK to continue!
    if [ x"$FOAMINSTALLFAILED" == "x" -o x"$FOAMINSTALLFAILED_BUTCONT" == "xYes" ]; then
      
      #build Qt
      build_Qt
      
      #build Paraview
      build_Paraview
      
      #build the PV3FoamReader plugin
      build_PV3FoamReader
      
      #build ccm26ToFoam
      build_ccm26ToFoam
      
    fi
  fi

  #final messages and instructions
  final_messages_for_clean_install

fi

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

