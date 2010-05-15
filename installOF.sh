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
#TODO 1 - Test and debug!

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

#Detect architecture and ubuntu version
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
    if [ "x$count_secs" == "x$2" ]; then
      break;
    fi
  done
}

function killgroup()
{
  if ps -p $1 > /dev/null; then
    TOKILLGROUP=$(ps x -o "%r %p" | awk "{ if ( \$2 == $1 ) { print \$1 }}")
    if [ "x$TOKILLGROUP" != "x" ]; then

      #make sure there are no unwanted survivors
      while true; do
        x=0

        #now get the processes that are to be killed
        TOKILL=$(ps x -o "%r %p" | awk "{ if ( \$1 == $TOKILLGROUP ) { print \$2 }}")

        #remove PIDS not to be killed
        for pids in $SAVEPIDS; do
          TOKILL=$(echo $TOKILL | sed -e "s/$pids//" -e 's/\ */\ /')
        done

        #now kill the ones in the kill list
        for pids in $TOKILL; do
          if ps -p $pids > /dev/null; then
            kill -SIGTERM $pids
            x=$(expr $x + 1)
          fi
        done

        if [ "$x" == "0" ]; then break; fi
      done
    fi
    unset TOKILL pids TOKILLGROUP
  fi
}

function save_running_pids()
{
  SAVEPIDS="$$"
  TONOTKILLGROUP=$(ps x -o "%r %p" | awk "{ if ( \$2 == $SAVEPIDS ) { print \$1 }}")
  SAVEPIDS=$(ps x -o "%r %p" | awk "{ if ( \$1 == $TONOTKILLGROUP ) { print \$2 }}")
  unset TONOTKILLGROUP
}

function cancel_installer()
{
    dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
--title "Cancel the Installer" \
--yesno 'Are you sure that you want to cancel the installer ??' 5 60 ;
    if [ x"$?" == x"0" ]; then
        clear
        exit
    fi
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
 OpenFOAM)
@@ -129,6 +132,8 @@
     compilerBin=$WM_COMPILER_DIR/bin
     compilerLib=$WM_COMPILER_DIR/lib$WM_COMPILER_LIB_ARCH:$WM_COMPILER_DIR/lib
     ;;
+System)
+    export WM_COMPILER_DIR=/usr
 esac
 
 if [ -d "$compilerBin" ]' | patch -p0

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
@@ -45,13 +45,13 @@                                                                       
 # note: script will try to determine the appropriate python library.                     
 #       If it fails, specify the path using the PYTHON_LIBRARY variable                  
 withPYTHON=false                                                                         
-PYTHON_LIBRARY=""
+PYTHON_LIBRARY="/usr/lib/libpython2.6.so"
 # PYTHON_LIBRARY="/usr/lib64/libpython2.6.so.1.0"

 # MESA graphics support:
 withMESA=false
 MESA_INCLUDE="/usr/include/GL"
-MESA_LIBRARY="/usr/lib64/libOSMesa.so"
+MESA_LIBRARY="/usr/lib/libOSMesa.so"

 # extra QT gui support (useful for re-using the installation for engrid)
 withQTSUPPORT=true
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
         export QMAKE_PATH=$2
--- ../makeParaViewFunctions     2009-07-24 13:51:14.000000000 +0100
+++ ./tools/makeParaViewFunctions       2010-05-15 18:39:33.000000000 +0100
@@ -167,7 +167,7 @@

 addQtSupport()
 {
-    [ "${withQTSUPPORT:=false}" = true ] || return
+  if [ "${withQTSUPPORT:=false}" = true ]; then

     addCMakeVariable "PARAVIEW_BUILD_QT_GUI=ON"

@@ -209,6 +209,11 @@
         echo "*** Error: cannot find qmake either at \$QMAKE_PATH or in current \$PATH"
         exit 1
     fi
+  else
+    addCMakeVariable "PARAVIEW_BUILD_QT_GUI=OFF"
+    addCMakeVariable "PointSpritePlugin_BUILD_EXAMPLES=OFF"
+    addCMakeVariable "PARAVIEW_BUILD_PLUGIN_PointSprite=OFF"
+  fi
 }

' | patch -p0
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
    leq804=$?
    isleftlarger_or_equal $version 10.04
    if [ "x$?" == "x1" -o "x$leq804" == "x1" ]; then
      THIRDPARTY_BIN_CMAKE="ThirdParty-1.6.linuxGcc.gtgz"
    fi
    unset leq804
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
  
  if [ "x$BUILD_QT" == "xYes" ]; then
    QT_VERSION=4.3.5
    QT_BASEURL="ftp://ftp.trolltech.com/qt/source/"
    QT_PACKAGEFILE="qt-x11-opensource-src-$QT_VERSION.tar.bz2"
  fi
  
  if [ "x$BUILD_CCM26TOFOAM" == "xYes" ]; then
    CCMIO_PACKAGE_VERSION=libccmio-2.6.1
    CCMIO_PACKAGE="${CCMIO_PACKAGE_VERSION}.tar.gz"
    CCMIO_BASEURL="https://wci.llnl.gov/codes/visit/3rd_party/"
    CCMIO_BASEURL_EXTRA_PRE="--no-check-certificate"
    CCMIO_MAKEFILES_FILES="files.AllwmakeLibccmio"
    CCMIO_MAKEFILES_OPTIONS="options.AllwmakeLibccmio"
  fi
}

#install packages in Ubuntu
function install_ubuntu_packages()
{
  #define which packages need to be installed
  PACKAGES_TO_INSTALL="w3m pv binutils-dev flex git-core build-essential python-dev libreadline5-dev wget zlib1g-dev cmake"

  #for Ubuntu 8.04, a few more packages are needed
  isleftlarger_or_equal 8.10 $version
  if [ x"$?" == x"1" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL curl"
  fi
  
  #for Ubuntu 10.04, a few more packages are needed
  isleftlarger_or_equal $version 10.04
  if [ x"$?" == x"1" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL libpng12-dev libxt-dev libxi-dev libxrender-dev libxrandr-dev libxcursor-dev libxinerama-dev libfreetype6-dev libfontconfig1-dev libglib2.0-dev"
  fi

  #for documentation, these are necessary
  if [ "x$BUILD_DOCUMENTATION" == "xdoc" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL doxygen graphviz"
  fi

  #for building gcc, these are necessary
  if [ "x$BUILD_GCC" == "xYes" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL texinfo byacc bison"
  fi

  if [ "$arch" == "x86_64" ]; then
    if [ "x$BUILD_GCC_STRICT_64BIT" != "xYes" -o "x$THIRDPARTY_BIN_CMAKE" != "x" ]; then
      PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL ia32-libs"
    fi
  fi

  #install qt4-dev and qt4-dev-tools only if the custom build isn't used
  if [ "x$BUILD_QT" != "xYes" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL libqt4-dev qt4-dev-tools"
  fi
  
  #install OSMesa when chosen for ParaView
  if [ "x$BUILD_PARAVIEW_WITH_OSMESA" == "xYes" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL libosmesa6 libosmesa6-dev"
  fi

  #now remove the ones that are already installed
  prune_packages_to_install
  
  #only show commands for installation if any packages are missing!
  if [ "x$PACKAGES_TO_INSTALL" != "x" ]; then

    #if permission granted
    if [ "x$SHOW_SUDO_COMMANDS_ONLY" != "xYES" ]; then

      echo 'The command "sudo apt-get update -y -q=1" is now going to be executed. Please provide sudo password if it asks you.'
      sudo apt-get update -y -q=1
      if [ "x$DOUPGRADE" == "xYes" ]; then
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
      if [ "x$DOUPGRADE" == "xYes" ]; then
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
  if [ "x$PACKAGES_TO_INSTALL" != "x" ]; then
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

#this function retrieves the md5sums from www.openfoam.com
#the retrieved checksums are stored in the file "OFpackages.md5"
function get_md5sums_for_OFpackages()
{
  w3m -dump -T text/html http://www.openfoam.com/download/linux32.php | grep gtgz | \
    sed -e 's/.*\(OpenFOAM.*\.gtgz\)[\ ]*\([a-z0-9]*$\)/\2  \1/' -e 's/.*\(ThirdParty.*\.gtgz\)[\ ]*\([a-z0-9]*$\)/\2  \1/' | \
    grep -e '^[a-z0-9]\{32\}' > OFpackages32.md5
  w3m -dump -T text/html http://www.openfoam.com/download/linux64.php | grep gtgz | \
    sed -e 's/.*\(OpenFOAM.*\.gtgz\)[\ ]*\([a-z0-9]*$\)/\2  \1/' -e 's/.*\(ThirdParty.*\.gtgz\)[\ ]*\([a-z0-9]*$\)/\2  \1/' | \
    grep -e '^[a-z0-9]\{32\}' > OFpackages64.md5
  cat OFpackages32.md5 OFpackages64.md5 | sort | uniq > OFpackages.md5
  rm -f OFpackages32.md5 OFpackages64.md5
}

# the 1st argument is the base address
# the 2nd argument is the file name
# the 3rd argument is the rest of the URL address
# the 4th argument is additional arguments to be given to wget before the URL
function do_wget()
{
  #either get the whole file, or try completing it, in case the user 
  #used previously Ctrl+C
  wget_string="$1$2"
  if [ "x$3" != "x" -a "x$3" != "x " ]; then
    wget_string="$wget_string$3"
  fi

  if [ "x$4" != "x" -a "x$4" != "x " ]; then
    if [ ! -e "$2" ]; then
      wget "$4" "$wget_string" 2>&1
    else
      wget -c "$4" "$wget_string" 2>&1
    fi
  else
    if [ ! -e "$2" ]; then
      wget "$wget_string" 2>&1
    else
      wget -c "$wget_string" 2>&1
    fi
  fi
  unset wget_string
}

#do a md5 checksum
#first argument is the file to check_installation
#second argument is the file where the check list is
function do_md5sum()
{
  set +e
  echo "Checking md5 checksum of file $1 ..."
  if [ x`grep $2 -e "$1" | md5sum -c | grep "$1: OK" | wc -l` == "x1" ]; then
    echo "File is OK."
    return 1
  else
    echo "File is NOT OK."
    return 0
  fi
  set -e
}

#this function will do wget and md5sum, and provide the possibility of 
#retrying to retrieve the same file in case of failure!
#arguments: first 3 are for wget, the last one is the file with the md5sum list
function do_wget_md5sum()
{
  while [ true ]; do
    do_wget "$1" "$2" "$3"
    do_md5sum "$2" "$4"
    if [ x"$?" == x"1" ]; then
      break;
    else
      echo -e "\nGetting the file '"$2"'seems to have failed for some reason. Do you want to try to download again? (yes or no): "
      read casestat;
      case $casestat in
        yes | y | Y | Yes | YES)
          rm -f "$2"
          ;;
        no | n | N | No | NO)
          break;
          ;;
      esac
    fi
  done
  unset casestat
}

#Download necessary files
function download_files()
{
  cd_openfoam #this is a precautionary measure

  #generate md5 sums for "md5sum -check"ing :)
  get_md5sums_for_OFpackages

  #Download Third Party files for detected system and selected mirror
  #download Third Party sources
  do_wget_md5sum "$OPENFOAM_SOURCEFORGE" "$THIRDPARTY_GENERAL" "$SOURCEFORGE_URL_OPTIONS" OFpackages.md5

  #download Third Party binaries, but only if requested and necessary!
  if [ "x$THIRDPARTY_BIN" != "x" ]; then
    do_wget_md5sum "$OPENFOAM_SOURCEFORGE" "$THIRDPARTY_BIN" "$SOURCEFORGE_URL_OPTIONS" OFpackages.md5
  fi
  
  if [ "x$THIRDPARTY_BIN_CMAKE" != "x" ]; then
    do_wget_md5sum "$OPENFOAM_SOURCEFORGE" "$THIRDPARTY_BIN_CMAKE" "$SOURCEFORGE_URL_OPTIONS" OFpackages.md5
  fi

  #download patch files that didn't fit in this script
  do_wget "$OPENFOAM_UBUNTU_SCRIPT_REPO" "$MPFRPATCHFILE"
  do_wget "$OPENFOAM_UBUNTU_SCRIPT_REPO" "$GCCMODED_MAKESCRIPT"
  do_wget "$OPENFOAM_UBUNTU_SCRIPT_REPO" "$WMAKEPATCHFILE"

  if [ "x$BUILD_QT" == "xYes" ]; then
    do_wget "$QT_BASEURL" "$QT_PACKAGEFILE"
  fi

  if [ "x$BUILD_CCM26TOFOAM" == "xYes" ]; then
    do_wget "$CCMIO_BASEURL" "$CCMIO_PACKAGE" " " "$CCMIO_BASEURL_EXTRA_PRE"
    do_wget "$OPENFOAM_UBUNTU_SCRIPT_REPO" "$CCMIO_MAKEFILES_FILES"
    do_wget "$OPENFOAM_UBUNTU_SCRIPT_REPO" "$CCMIO_MAKEFILES_OPTIONS"
  fi
}

#Unpack downloaded files
function unpack_downloaded_files()
{
  cd_openfoam #this is a precautionary measure

  echo "------------------------------------------------------"
  echo "Untar files -- This can take time"
  echo "Untaring $THIRDPARTY_GENERAL"
  #TODO: option "-n" in "pv" will allow the usage of "dialog --gauge" :)
  pv $THIRDPARTY_GENERAL | tar -xz
  
  #check if $THIRDPARTY_BIN is provided, because one could want to build from sources
  if [ "x$THIRDPARTY_BIN" != "x" ]; then 
    cd_openfoam
    echo "Untaring $THIRDPARTY_BIN"
    pv $THIRDPARTY_BIN | tar -xz
  fi
  
  #needed for Ubuntu 8.04 and 10.04 x86_64
  if [ "x$THIRDPARTY_BIN_CMAKE" != "x" ]; then 
    cd_openfoam
    echo "Untaring $THIRDPARTY_BIN_CMAKE"
    pv $THIRDPARTY_BIN_CMAKE | tar -xz ThirdParty-1.6/cmake-2.6.4
    cd ThirdParty-1.6/cmake-2.6.4/platforms/
    #this is necessary, since there isn't a pre-build made for 64bit
    ln -s linux linux64
  fi
  
  if [ "x$BUILD_QT" == "xYes" ]; then
    cd_openfoam
    cd ThirdParty-1.6
    echo "Untaring $QT_PACKAGEFILE"
    pv ../$QT_PACKAGEFILE | tar xj 
  fi

  if [ "x$BUILD_CCM26TOFOAM" == "xYes" ]; then
    cd_openfoam
    cd ThirdParty-1.6
    ln -s ../$CCMIO_PACKAGE $CCMIO_PACKAGE
    #NOTE: unpacking will be done by the AllwmakeLibccmio script
    if [ -e "../$CCMIO_MAKEFILES_FILES" -a -e "../$CCMIO_MAKEFILES_OPTIONS" ]; then
      if [ ! -d "wmakeFiles/libccmio/Make" ]; then
        mkdir -p wmakeFiles/libccmio/Make
      fi
      cp "../$CCMIO_MAKEFILES_FILES" wmakeFiles/libccmio/Make/files
      cp "../$CCMIO_MAKEFILES_OPTIONS" wmakeFiles/libccmio/Make/options
    fi
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
  #The total count of "make[.]" found in our build_Qt.log
  BUILD_QT_LAST_BUILD_COUNT=293

  #TODO: this value is hard coded for now, since it should come from the output of our timmings script
  #The total count of "make[.]" found in our build_gcc.log
  BUILD_GCC_LAST_BUILD_COUNT=556
  
  #NOTES: ParaView has its own percentage, so we just lift from it
  #NOTES: OpenFOAM uses wmake, making it relatively easier to estimate automatically, 
  #thus automatically adapting to new additions in the git repository
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
    unlink "$PATHOF/ThirdParty-1.6.x"
  fi
  ln -s "$PATHOF/ThirdParty-1.6" "$PATHOF/ThirdParty-1.6.x"
  git clone http://repo.or.cz/r/OpenFOAM-1.6.x.git
}


function link_gcc433_libraries_to_system()
{
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
}

#apply patches and fixes
function apply_patches_fixes()
{
  cd_openfoam #this is a precautionary measure

  #FIXES ------
  
  #fix links to proper libraries for gcc, as long as the OpenFOAM's precompiled version is used
  isleftlarger_or_equal $version 9.10
  if [ x"$?" == x"1" -a "x$USE_OF_GCC" == "xYes" ]; then
    link_gcc433_libraries_to_system
  fi
  
  #fix ParaView's help file reference, for when ParaView isn't built
  if [ "x$BUILD_PARAVIEW" != "xYes" ]; then
    cd_openfoam
    if [ x`echo $arch | grep -e "i.86"` != "x" ]; then
      cd ThirdParty-1.6/paraview-3.6.1/platforms/linuxGcc/bin
    elif [ "$arch" == "x86_64" ]; then
      cd ThirdParty-1.6/paraview-3.6.1/platforms/linux64Gcc/bin
    fi
    mv pqClientDocFinder.txt pqClientDocFinder_orig.txt
    cat pqClientDocFinder_orig.txt | sed 's/\/home\/dm2\/henry\/OpenFOAM/'${PATHOF}'/' > ./pqClientDocFinder.txt
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
  if [ "x$USE_OF_GCC" == "xNo" ]; then
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
  cd_openfoam
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
  if [ "x$USE_ALIAS_FOR_BASHRC" == "xYes" ]; then
    echo -e "alias startFoam=\". $PATHOF/OpenFOAM-1.6.x/etc/bashrc\"" >> ~/.bashrc
  else
    echo ". $PATHOF/OpenFOAM-1.6.x/etc/bashrc" >> ~/.bashrc
  fi
}

#provide the user with a progress bar and timings for building gcc
function build_gcc_progress_dialog()
{
  if [ "x$BUILD_GCC_MUST_KILL" == "xYes" ]; then

    echo -e "\n\nKill code issued... please wait..."
    echo -e "NOTE: The kill code will take a few seconds to affect all child processes."
    killgroup $BUILD_GCC_PID

  else

    ( #while true is used as a containment cycle...
    while true;
    do
      if [ -e "$BUILD_GCC_LOG" ]; then
        BUILD_GCC_MAKECOUNT=`grep 'make\[.\]' "$BUILD_GCC_LOG" | wc -l`
        nowpercent=`expr $BUILD_GCC_MAKECOUNT \* 100 / $BUILD_GCC_LAST_BUILD_COUNT`
      fi
      if [ "x$nowpercent" != "x$percent" ]; then
        percent=$nowpercent
        BUILD_GCC_UPDATE_TIME=`date`
      fi
      echo $percent
      echo "XXX"
      echo "Build gcc-4.3.3:"
      echo "The build process is going to be logged in the file:"
      echo "  $BUILD_GCC_LOG"
      echo "If you want to, you can follow the progress of this build"
      echo "process, by opening a new terminal and running:"
      echo "  tail -F $BUILD_GCC_LOG"
      echo "Either way, please wait, this will take a while..."
      echo -e "\nQt started to build at:\n\t$BUILD_GCC_START_TIME\n"
      echo -e "Last progress update made at:\n\t$BUILD_GCC_UPDATE_TIME"
      echo "XXX"

      #this provides a better monitorization of the process itself... i.e., if it has already stopped!
      #30 second update
      monitor_sleep $BUILD_GCC_PID 30

      if ! ps -p $BUILD_GCC_PID > /dev/null; then
        break;
      fi
    done
    ) | dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
        --title "Building gcc" --gauge "Starting..." 20 80 $percent
  fi

  #monitor here too, to wait for kill code, when issued
  monitor_sleep $BUILD_GCC_PID 30
}

#this indicates to the user that we have it under control...
function build_gcc_ctrl_c_triggered()
{
  BUILD_GCC_MUST_KILL="Yes"
  build_gcc_progress_dialog
}

#build gcc that comes with OpenFOAM
function build_openfoam_gcc()
{
  if [ "x$BUILD_GCC" == "xYes" ]; then
    
    #set up environment, just in case we forget about it!
    if [ "x$WM_PROJECT_DIR" == "x" ]; then
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
    
    #set up traps...
    trap build_gcc_ctrl_c_triggered SIGINT SIGQUIT SIGTERM

    echo "------------------------------------------------------"
    echo "Build gcc:"
    
    #launch makeGcc asynchronously
    bash -c "time ./$GCCMODED_MAKESCRIPT $BUILD_GCC_OPTION" > "$BUILD_GCC_LOG" 2>&1 &
    BUILD_GCC_PID=$!
    BUILD_GCC_START_TIME=`date`
    BUILD_GCC_UPDATE_TIME=$BUILD_GCC_START_TIME

    #track build progress
    percent=0
    build_gcc_progress_dialog
    
    #wait for kill code to change
    clear
    if ! ps -p $BUILD_GCC_PID > /dev/null && [ "x$BUILD_GCC_MUST_KILL" != "x" ]; then
      echo "Kill code issued with success. The script will continue execution."
    fi

    #clear traps
    trap - SIGINT SIGQUIT SIGTERM
    
    echo "------------------------------------------------------"
    echo "Build gcc-4.3.3:"
    if [ -e "$BUILD_GCC_ROOT/bin/gcc" ]; then
      echo -e "gcc started to build at:\n\t$BUILD_GCC_START_TIME\n"
      echo -e "Building gcc finished successfully at:\n\t`date`"
      echo "gcc is ready to be used."

      #TODO: this won't be necessary if we build cmake too, since then there won't be 
      #any more dependencies to the system's libraries!
      if [ "$arch" == "x86_64" -a "x$THIRDPARTY_BIN_CMAKE" != "x" ]; then
        link_gcc433_libraries_to_system
      fi
    else
      echo "Build process didn't finished with success. Please check the log file for more information:"
      echo -e "\t$BUILD_GCC_LOG"
      echo "You can post it at this forum thread:"
      echo "  http://www.cfd-online.com/Forums/openfoam-installation/73805-openfoam-1-6-x-installer-ubuntu.html"
      echo -e '\nYou can also verify that thread for other people who might have had the same problems.'
      BUILD_GCC_FAILED="Yes"
    fi
    echo "------------------------------------------------------"
    
  fi
}

#provide the user with a progress bar and timings for building OpenFOAM
function build_awopenfoam_progress_dialog()
{
  if [ "x$BUILD_AWOPENFOAM_MUST_KILL" == "xYes" ]; then
    echo -e "\n\nKill code issued... please wait..."
    echo -e "NOTE: The kill code will take a few seconds to affect all child processes."
    killgroup $BUILD_AWOPENFOAM_PID

  else

    ( #while true is used as a containment cycle...
    while true;
    do
      if [ "x$BUILD_AWOPENFOAMDOC_START_TIME" == "x" -a -e "$BUILD_AWOPENFOAM_LOG" ]; then
        BUILD_AWOPENFOAM_MAKECOUNT=`grep 'WMAKE timing start' "$BUILD_AWOPENFOAM_LOG" | wc -l`
        nowpercent=`expr $BUILD_AWOPENFOAM_MAKECOUNT \* 100 / $BUILD_AWOPENFOAM_ESTIM_BUILD_COUNT`
      else
        if [ -e "$BUILD_AWOPENFOAMDOC_LOG" ]; then
          BUILD_AWOPENFOAM_NOWCOUNT=`cat "$BUILD_AWOPENFOAMDOC_LOG" | grep -e "^Parsing file" -e "^Generating code for file" -e "^Generating docs for" -e "^Generating dependency graph for directory" | wc -l`
          nowpercent=`expr $BUILD_AWOPENFOAM_NOWCOUNT \* 100 / $BUILD_AWOPENFOAMDOC_ESTIMCOUNT`
        fi
      fi
      
      if [ "x$nowpercent" != "x$percent" ]; then
        percent=$nowpercent
        BUILD_AWOPENFOAM_UPDATE_TIME=`date`
      fi
      echo $percent
      echo "XXX"
      echo "Build OpenFOAM:"
      if [ "x$BUILD_AWOPENFOAMDOC_START_TIME" == "x" ]; then
        echo "The Allwmake build process is going to be logged in the file:"
        echo "  $BUILD_AWOPENFOAM_LOG"
        echo "If you want to, you can follow the progress of this build"
        echo "process, by opening a new terminal and running:"
        echo "  tail -F $BUILD_AWOPENFOAM_LOG"
      else
        echo "The Doxygen build process is going to be logged in the file:"
        echo "  $BUILD_AWOPENFOAMDOC_LOG"
        echo "If you want to, you can follow the progress of this build"
        echo "process, by opening a new terminal and running:"
        echo "  tail -F $BUILD_AWOPENFOAMDOC_LOG"
      fi
      echo "WARNING: THIS CAN TAKE HOURS..."
      echo -e "\nAllwmake started to build at:\n\t$BUILD_AWOPENFOAM_START_TIME"
      if [ "x$BUILD_AWOPENFOAMDOC_START_TIME" != "x" ]; then
        echo -e "Allwmake finished building at:\n\t$BUILD_AWOPENFOAM_END_TIME\n"
        echo -e "Doxygen started to build OpenFOAM code documentation at:\n\t$BUILD_AWOPENFOAMDOC_START_TIME"
      fi
      echo -e "\nLast progress update made at:\n\t$BUILD_AWOPENFOAM_UPDATE_TIME"
      echo "XXX"

      #TODO: still have to redo the build estimation. For now it will be disabled.
      ##calcestimate
      ##estimated_timed=$?
      ##echo "Estimated time it will take: $estimated_timed minutes."
      ##echo "Total time that it did take will be shown upon completion."

      #this provides a better monitorization of the process itself... i.e., if it has already stopped!
      #30 second update
      monitor_sleep $BUILD_AWOPENFOAM_PID 30

      if ! ps -p $BUILD_AWOPENFOAM_PID > /dev/null; then
        if [ "x$BUILD_DOCUMENTATION" != "x" ]; then
          if [ "x$BUILD_AWOPENFOAMDOC_START_TIME" == "x" ]; then
            #first calculate estimate
            percent=0
            echo $percent
            echo "XXX"
            echo "Calculating estimate for documentation progress..."
            echo "XXX"
            BUILD_AWOPENFOAMDOC_FILECOUNT=`find * | grep -v "/lnInclude/" | grep -v "/t/" | grep -e "^src/" -e "^applications/utilities" -e "^applications/solvers" | grep -e ".H$" -e ".C$" | wc -l`
            BUILD_AWOPENFOAMDOC_ESTIMCOUNT=`expr $BUILD_AWOPENFOAMDOC_FILECOUNT \* 385 / 100`
            cd doc
            echo "Now it's going to build the documentation..."
            BUILD_AWOPENFOAMDOC_LOG="$WM_PROJECT_DIR/docmake.log"
            BUILD_AWOPENFOAM_END_TIME=`date`
            #launch wmake all asynchronously
            bash -c "time wmake all > ${BUILD_AWOPENFOAMDOC_LOG} 2>&1" >> ${BUILD_AWOPENFOAMDOC_LOG} 2>&1 &
            BUILD_AWOPENFOAM_PID=$!
            BUILD_AWOPENFOAMDOC_START_TIME=`date`
            BUILD_AWOPENFOAM_UPDATE_TIME=$BUILD_AWOPENFOAMDOC_START_TIME
            cd ..
          else
            break;
          fi
        else
          break;
        fi
      fi
    done
    ) | dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
        --title "Building OpenFOAM" --gauge "Starting..." 24 80 $percent
  fi

  #monitor here too, to wait for kill code, when issued
  monitor_sleep $BUILD_AWOPENFOAM_PID 30
}

#this indicates to the user that we have it under control...
function build_awopenfoam_ctrl_c_triggered()
{
  BUILD_AWOPENFOAM_MUST_KILL="Yes"
  build_awopenfoam_progress_dialog
}

#do an Allwmake on OpenFOAM 1.6.x
function allwmake_openfoam()
{
  #set up environment, just in case we forget about it!
  if [ "x$WM_PROJECT_DIR" == "x" ]; then
    setOpenFOAMEnv
  fi

  cd $WM_PROJECT_DIR
  BUILD_AWOPENFOAM_LOG="$WM_PROJECT_DIR/make.log"

  #set up traps...
  trap build_awopenfoam_ctrl_c_triggered SIGINT SIGQUIT SIGTERM

  export WM_DO_TIMINGS="Yes"

  echo "------------------------------------------------------"
  echo "Build OpenFOAM:"
  echo "Calculating building estimates, please wait..."
  #wmake is called once for each Make folder and for each Allwmake
  BUILD_AWOPENFOAM_ESTIM_BUILD_COUNT1=`find ${WM_PROJECT_DIR}/* | grep -v "/applications/test" | grep -v "/Optional" | grep -v "/doc/" | grep -e "Make/files" -e "Allwmake" | wc -l`
  BUILD_AWOPENFOAM_ESTIM_BUILD_COUNT2=`find ${WM_THIRD_PARTY_DIR}/* | grep -e "Make/options" -e "Allwmake" | wc -l`
  #wmake count should also include the first call... and at least 1 more just in case...
  BUILD_AWOPENFOAM_ESTIM_BUILD_COUNT=`expr $BUILD_AWOPENFOAM_ESTIM_BUILD_COUNT1 + $BUILD_AWOPENFOAM_ESTIM_BUILD_COUNT2 + 2`
  unset BUILD_AWOPENFOAM_ESTIM_BUILD_COUNT1 BUILD_AWOPENFOAM_ESTIM_BUILD_COUNT2
  echo "------------------------------------------------------"

  #launch wmake all asynchronously
  #bash -c is the only way I got for getting time results straight to display and also logged
  bash -c "time wmake all > make.log 2>&1" >> make.log 2>&1 &
  BUILD_AWOPENFOAM_PID=$!
  BUILD_AWOPENFOAM_START_TIME=`date`
  BUILD_AWOPENFOAM_UPDATE_TIME=$BUILD_AWOPENFOAM_START_TIME

  #track build progress
  percent=0
  build_awopenfoam_progress_dialog
  
  #wait for kill code to change
  clear
  if ! ps -p $BUILD_AWOPENFOAM_PID > /dev/null && [ "x$BUILD_AWOPENFOAM_MUST_KILL" != "x" ]; then
    echo "Kill code issued with success. The script will continue execution."
  fi

  #clear traps
  trap - SIGINT SIGQUIT SIGTERM

  export WM_DO_TIMINGS=
  echo "------------------------------------------------------"
  echo "Build OpenFOAM:"
  echo -e "Allwmake started to build at:\n\t$BUILD_AWOPENFOAM_START_TIME\n"
  if [ "x$BUILD_AWOPENFOAMDOC_START_TIME" == "x" ]; then
    echo -e "Allwmake finished at:\n\t`date`"
  else
    echo -e "Allwmake + Doxygen finished at:\n\t`date`"
  fi
  echo "------------------------------------------------------"
}

function continue_after_failed_openfoam()
{
  if [ "x$FOAMINSTALLFAILED" != "x" ]; then
    FOAMINSTALLFAILED_BUTCONT="No"
    echo -e "\n------------------------------------------------------\n"
    echo "Although the previous step seems to have failed, do you wish to continue with the remaining steps?"
    
    if [ "x$BUILD_CCM26TOFOAM" == "xYes" -o "x$BUILD_PARAVIEW" == "xYes" -o "x$BUILD_QT" == "xYes" ]; then 
      echo "Missing steps are:"
      if [ "x$BUILD_QT" == "xYes" ]; then echo "- Building Qt"; fi
      if [ "x$BUILD_PARAVIEW" == "xYes" ]; then echo "- Building ParaView"; fi
      if [ "x$BUILD_CCM26TOFOAM" == "xYes" ]; then echo "- Building ccm26ToFoam"; fi
    fi

    echo "Continue? (yes or no): "
    read casestat;
    case $casestat in
      yes | y | Y | Yes | YES) FOAMINSTALLFAILED_BUTCONT="Yes";;
    esac
    unset casestat
    echo "------------------------------------------------------"
  fi
}

#check if the installation is complete
function check_installation()
{
  #set up environment, just in case we forget about it!
  if [ "x$WM_PROJECT_DIR" == "x" ]; then
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
    if [ "x$FOAM_TUTORIALS" == "x" ]; then
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
  echo "------------------------------------------------------"
  if [ "x$FOAMINSTALLFAILED" == "x" ]; then

    #If using bash alias, inform to use it to run!
    if [ "x$USE_ALIAS_FOR_BASHRC" == "xYes" ]; then
      echo "Installation complete - You have chosen to use bash alias"
      echo "To start using OpenFOAM, you'll have to start a new terminal first;"
      echo -e "then, type:\n\tstartFoam\nto activate the OpenFOAM environment."
      echo "------------------------------------------------------"
    else
      echo "Installation complete"
      echo "To start using OpenFOAM, you'll have to start a new terminal first."
      echo "------------------------------------------------------"
    fi
  
  else

    echo "Installation failed. Please don't forget to check the provided forum link for solutions on the provided link, and/or report the error."
    if [ "x$USE_ALIAS_FOR_BASHRC" == "xYes" ]; then
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
  if [ "x$WM_PROJECT_DIR" == "x" ]; then
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
  if [ "x$BUILD_QT_MUST_KILL" == "xYes" ]; then
    echo -e "\n\nKill code issued... please wait..."
    echo -e "NOTE: The kill code will take a few seconds to affect all child processes."
    killgroup $BUILD_QT_PID

  else
    
    ( #while true is used as a containment cycle...
    while true;
    do
      if [ -e "$BUILD_QT_LOG" ]; then
        BUILD_QT_MAKECOUNT=`grep 'make\[.\]' "$BUILD_QT_LOG" | wc -l`
        nowpercent=`expr $BUILD_QT_MAKECOUNT \* 100 / $BUILD_QT_LAST_BUILD_COUNT`
      fi
      if [ "x$nowpercent" != "x$percent" ]; then
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
      echo -e "\nQt started to build at:\n\t$BUILD_QT_START_TIME\n"
      echo -e "Last progress update made at:\n\t$BUILD_QT_UPDATE_TIME"
      echo "XXX"

      #this provides a better monitorization of the process itself... i.e., if it has already stopped!
      #30 second update
      monitor_sleep $BUILD_QT_PID 30

      if ! ps -p $BUILD_QT_PID > /dev/null; then
        break;
      fi
    done
    ) | dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
        --title "Building Qt" --gauge "Starting..." 20 80 $percent

  fi

  #monitor here too, to wait for kill code, when issued
  monitor_sleep $BUILD_QT_PID 30
}

#this indicates to the user that we have it under control...
function build_Qt_ctrl_c_triggered()
{
  BUILD_QT_MUST_KILL="Yes"
  build_Qt_progress_dialog
}

function build_Qt()
{
  if [ "x$BUILD_QT" == "xYes" ]; then
    #set up environment, just in case we forget about it!
    if [ "x$WM_PROJECT_DIR" == "x" ]; then
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

    echo "------------------------------------------------------"
    echo "Build Qt:"
    
    #launch makeQt asynchronously
    bash -c "time ./makeQt --confirm-license=yes" > "$BUILD_QT_LOG" 2>&1 &
    BUILD_QT_PID=$!
    BUILD_QT_START_TIME=`date`
    BUILD_QT_UPDATE_TIME=$BUILD_QT_START_TIME

    #track build progress
    percent=0
    build_Qt_progress_dialog
    
    #wait for kill code to change
    clear
    if ! ps -p $BUILD_QT_PID > /dev/null && [ "x$BUILD_QT_MUST_KILL" != "x" ]; then
      echo "Kill code issued with success. The script will continue execution."
    fi

    #clear traps
    trap - SIGINT SIGQUIT SIGTERM
    
    echo "------------------------------------------------------"
    echo "Build Qt ${QT_VERSION}:"
    if [ -e "$QT_PLATFORM_PATH/bin/qmake" ]; then
      echo -e "Qt started to build at:\n\t$BUILD_QT_START_TIME\n"
      echo -e "Building Qt finished successfully at:\n\t`date`"
      echo "Qt is ready to use for building ParaView."
    else
      echo "Build process didn't finished with success. Please check the log file for more information:"
      echo -e "\t$BUILD_QT_LOG"
      echo "You can post it at this forum thread:"
      echo "  http://www.cfd-online.com/Forums/openfoam-installation/73805-openfoam-1-6-x-installer-ubuntu.html"
      echo -e '\nYou can also verify that thread for other people who might have had the same problems.'
      BUILDING_QT_FAILED="Yes"
    fi
    echo "------------------------------------------------------"

  fi
}

#provide the user with a progress bar and timings for building ParaView
function build_ParaView_progress_dialog()
{
  if [ "x$BUILD_PARAVIEW_MUST_KILL" == "xYes" ]; then
    echo -e "\n\nKill code issued... please wait..."
    echo -e "NOTE: The kill code will take a few seconds to affect all child processes."
    killgroup $BUILD_PARAVIEW_PID

  else
    ( #while true is used as a containment cycle...
    while true;
    do
      #get progress value
      if [ -e "$PARAVIEW_BUILD_LOG" ]; then
        BUILD_PARAVIEW_PROGRESS=`cat "$PARAVIEW_BUILD_LOG" | grep "^\[" | tail -n 1 | sed 's/^\[\([ 0-9]*\).*/\1/' | sed 's/\ *//'`
      fi
      if [ "x$BUILD_PARAVIEW_PROGRESS" != "x" -a "x$BUILD_PARAVIEW_PROGRESS" != "x$percent" ]; then
        percent=$BUILD_PARAVIEW_PROGRESS
        BUILD_PARAVIEW_UPDATE_TIME=`date`
      fi
      
      #get current build stage
      BUILD_PARAVIEW_ISNOWATDOC=`cat "$PARAVIEW_BUILD_LOG" | grep "Creating html documentation" | wc -l`
      BUILD_PARAVIEW_ISNOWFINALIZING=`cat "$PARAVIEW_BUILD_LOG" | grep "Replacing path hard links for" | wc -l`

      echo $percent
      echo "XXX"
      echo "Build ParaView:"
      echo "The build process is going to be logged in the file:"
      echo "  $PARAVIEW_BUILD_LOG"
      echo "If you want to, you can follow the progress of this build"
      echo "process, by opening a new terminal and running:"
      echo "  tail -F $PARAVIEW_BUILD_LOG"
      echo "Either way, please wait, this will take a while..."
      echo -e "\nParaView started to build at:\n\t$BUILD_PARAVIEW_START_TIME\n"
      echo -e "Last progress update made at:\n\t$BUILD_PARAVIEW_UPDATE_TIME\n"
      
      if [ "x$BUILD_PARAVIEW_ISNOWATDOC" != "x0" -a "x$BUILD_PARAVIEW_ISNOWFINALIZING" == "x0" ]; then
        echo "Building HTML documentation for ParaView..."
      elif [ "x$BUILD_PARAVIEW_ISNOWFINALIZING" != "x0" ]; then
        echo "Finalizing... almost complete..."
      fi
      
      echo "XXX"

      #this provides a better monitorization of the process itself... i.e., if it has already stopped!
      #30 second update
      monitor_sleep $BUILD_PARAVIEW_PID 30

      if ! ps -p $BUILD_PARAVIEW_PID > /dev/null; then
        break;
      fi
    done
    ) | dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
        --title "Building ParaView" --gauge "Starting..." 20 80 $percent

  fi

  #monitor here too, to wait for kill code, when issued
  monitor_sleep $BUILD_PARAVIEW_PID 30
}

#this indicates to the user that we have it under control...
function build_ParaView_ctrl_c_triggered()
{
  BUILD_PARAVIEW_MUST_KILL="Yes"
  build_ParaView_progress_dialog
}

function build_ParaView()
{
  if [ "x$BUILD_PARAVIEW" == "xYes" ]; then
    
    if [ "x$BUILD_QT" == "xYes" -a "x$BUILDING_QT_FAILED" == "xYes" ]; then

      echo "------------------------------------------------------"
      echo "The requested Qt is unavailable, thus rendering impossible to build ParaView with it."
      echo "------------------------------------------------------"

    else

      #set up environment, just in case we forget about it!
      if [ "x$WM_PROJECT_DIR" == "x" ]; then
        setOpenFOAMEnv
      fi

      cd $WM_THIRD_PARTY_DIR

      #purge existing ParaView
      if [ -e "$ParaView_DIR" ]; then
        rm -rf $ParaView_DIR
      fi 

      PARAVIEW_BUILD_OPTIONS=""
      if [ "x$BUILD_QT" == "xYes" ]; then
        PARAVIEW_BUILD_OPTIONS="$PARAVIEW_BUILD_OPTIONS -qmake \"$QT_PLATFORM_PATH/bin/qmake\""
      fi

      if [ "x$BUILD_PARAVIEW_WITH_GUI" == "xNo" ]; then
        PARAVIEW_BUILD_OPTIONS="$PARAVIEW_BUILD_OPTIONS -noqt"
      fi

      if [ "x$BUILD_PARAVIEW_WITH_MPI" == "xYes" ]; then
        PARAVIEW_BUILD_OPTIONS="$PARAVIEW_BUILD_OPTIONS -mpi"
      fi

      if [ "x$BUILD_PARAVIEW_WITH_PYTHON" == "xYes" ]; then
        PARAVIEW_BUILD_OPTIONS="$PARAVIEW_BUILD_OPTIONS -python"
      fi

      if [ "x$BUILD_PARAVIEW_WITH_OSMESA" == "xYes" ]; then
        PARAVIEW_BUILD_OPTIONS="$PARAVIEW_BUILD_OPTIONS -mesa"
      fi

      PARAVIEW_BUILD_LOG="$WM_THIRD_PARTY_DIR/build_ParaView.log"

      #set up traps...
      trap build_ParaView_ctrl_c_triggered SIGINT SIGQUIT SIGTERM

      echo "------------------------------------------------------"
      echo "Build ParaView:"

      #launch makeParaView asynchronously
      bash -c "time ./makeParaView $PARAVIEW_BUILD_OPTIONS" > "$PARAVIEW_BUILD_LOG" 2>&1 &
      BUILD_PARAVIEW_PID=$!
      BUILD_PARAVIEW_START_TIME=`date`
      BUILD_PARAVIEW_UPDATE_TIME=$BUILD_PARAVIEW_START_TIME
      
      #track build progress
      percent=0
      build_ParaView_progress_dialog

      #wait for kill code to change
      clear
      if ! ps -p $BUILD_PARAVIEW_PID > /dev/null && [ "x$BUILD_PARAVIEW_MUST_KILL" != "x" ]; then
        echo "Kill code issued with success. The script will continue execution."
      fi

      #clear traps
      trap - SIGINT SIGQUIT SIGTERM

      echo "------------------------------------------------------"
      echo "Build ParaView:"
      if [ -e "$ParaView_DIR/bin/paraview" ]; then

        echo -e "ParaView started to build at:\n\t$BUILD_PARAVIEW_START_TIME\n"
        echo -e "Building ParaView finished successfully at:\n\t`date`"
        echo "ParaView is ready to use."

      elif [ "x$BUILD_PARAVIEW_WITH_GUI" == "xNo" -a "x$BUILD_PARAVIEW_WITH_MPI" == "xYes" -a \
             -e "$ParaView_DIR/bin/pvserver" -a -e "$ParaView_DIR/bin/pvrenderserver" -a \
             -e "$ParaView_DIR/bin/pvdataserver" ]; then

        echo -e "ParaView started to build at:\n\t$BUILD_PARAVIEW_START_TIME\n"
        echo -e "Building ParaView finished successfully at:\n\t`date`"
        echo "ParaView server tools are ready to be used."

      else

        echo "Build process didn't finished with success. Please check the log file for more information:"
        echo -e "\t$PARAVIEW_BUILD_LOG"
        echo "You can post it at this forum thread:"
        echo "  http://www.cfd-online.com/Forums/openfoam-installation/73805-openfoam-1-6-x-installer-ubuntu.html"
        echo -e '\nYou can also verify that thread for other people who might have had the same problems.'
        BUILDING_PARAVIEW_FAILED="Yes"
        #TODO: do something more with BUILDING_PARAVIEW_FAILED, like final error listing and suggestions
      fi
      echo "------------------------------------------------------"

    fi
  fi
}

function build_PV3FoamReader()
{
  if [ "x$BUILD_PARAVIEW" == "xYes" ]; then
    
    #set up environment, just in case we forget about it!
    if [ "x$WM_PROJECT_DIR" == "x" ]; then
      setOpenFOAMEnv
    fi

    if [ "x$BUILD_QT" == "xYes" -a "x$BUILDING_QT_FAILED" == "xYes" ]; then

      echo "------------------------------------------------------"
      echo "No Qt, no ParaView, thus no PV3FoamReader."
      echo "------------------------------------------------------"

    elif [ ! -e "$ParaView_DIR/bin/paraview" ]; then
      
      echo "------------------------------------------------------"
      echo "ParaView isn't available where it is expected:"
      echo "  $ParaView_DIR/bin/paraview"
      echo "Therefore it isn't possible to proceed with building the plugin PV3FoamReader."
      echo "------------------------------------------------------"
      
    else

      cd "$FOAM_UTILITIES/postProcessing/graphics/PV3FoamReader"
      
      PV3FOAMREADER_BUILD_LOG="$WM_PROJECT_DIR/build_PV3FoamReader.log"

      echo "------------------------------------------------------"
      echo "Build PV3FoamReader for ParaView:"
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
        echo "Build process didn't finished with success. Please check the log file for more information:"
        echo -e "\t$PV3FOAMREADER_BUILD_LOG"
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
  
  if [ "x$BUILD_CCM26TOFOAM" == "xYes" ]; then
    #set up environment, just in case we forget about it!
    if [ "x$WM_PROJECT_DIR" == "x" ]; then
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
      echo "Build process didn't finished with success. Please check the log file for more information:"
      echo -e "\t$BUILD_CCM26TOFOAM_LOG"
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
while : ; do
  PATHOF=$(dialog --stdout \
  --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
  --inputbox 'Choose the install path: < default: ~/OpenFOAM >' 8 60 ~/OpenFOAM ) 

  if [ x"$?" == x"0" ]; then
    break;
  else
    cancel_installer
  fi
done

#Logging option Dialog
while : ; do
  LOG_OUTPUTS=$(dialog --stdout \
  --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
  --menu 'Do you want to save a log of the script? < default: Yes >' 0 40 0 \
  'Yes'   '' \
  'No' '' )

  if [ x"$?" == x"0" ]; then
    break;
  else
    cancel_installer
  fi
done

#Installation mode dialog
while : ; do
  INSTALLMODE=$(dialog --stdout \
  --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"    \
  --radiolist 'Choose the Install Mode: < default: fresh >' 10 50 3 \
  'fresh' 'Make new Install' on  \
  'update'   'Update currenty install'           off \
  'server'    'ParaView with: -GUI +MPI'    off )

  if [ x"$?" == x"0" ]; then
    break;
  else
    cancel_installer
  fi
done

if [ "x$INSTALLMODE" != "xupdate" ]; then

  #Settings choosing Dialog
  while : ; do
    SETTINGSOPTS=$(dialog --stdout --separate-output \
    --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
    --checklist "Choose Install settings: < Space to select ! >" 15 50 5 \
    1 "Do apt-get upgrade" off \
    2 "Build OpenFOAM docs" off \
    3 "Use startFoam alias" on \
    4 "Use OpenFOAM gcc compiler" on \
    5 "Build ccm26ToFoam" off )

    if [ x"$?" == x"0" ]; then
      break;
    else
      cancel_installer
    fi
  done

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
  BUILD_PARAVIEW_WITH_OSMESA=No
  #ParaView configurations for a fresh install
  if [ "$INSTALLMODE" == "fresh" ]; then
    while : ; do
      PVSETTINGSOPTS=$(dialog --stdout --separate-output \
      --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
      --checklist "Choose ParaView settings: < Space to select ! >" 16 52 6 \
      1 "Do custom build of QT 4.3.5 ?" off \
      2 "Do custom build of ParaView ?" off \
      3 "Build ParaView with GUI ?" on \
      4 "Build ParaView with Python support ?" off \
      5 "Build ParaView with MPI support ?" off \
      6 "Build ParaView with OSMesa support ?" off )

      if [ x"$?" == x"0" ]; then
        break;
      else
        cancel_installer
      fi
    done
  fi

  #Take care of unpack settings from PVSETTINGSOPTS
  for setting in $PVSETTINGSOPTS ; do
    if [ $setting == 1 ] ; then BUILD_QT=Yes ; fi
    if [ $setting == 2 ] ; then BUILD_PARAVIEW=Yes ; fi
    if [ $setting == 3 ] ; then BUILD_PARAVIEW_WITH_GUI=Yes ; fi
    if [ $setting == 4 ] ; then BUILD_PARAVIEW_WITH_PYTHON=Yes ; fi
    if [ $setting == 5 ] ; then BUILD_PARAVIEW_WITH_MPI=Yes ; fi
    if [ $setting == 6 ] ; then BUILD_PARAVIEW_WITH_OSMESA=Yes ; fi
  done

  if [ "$version" == "10.04" -a "x$BUILD_PARAVIEW" != "xYes" ]; then
      BUILD_PARAVIEW=Yes
      dialog --sleep 6 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
      --title "Non-optional setting detected!" \
      --infobox "You are running Ubuntu $version.\nFor ParaView to work properly this script must do a custom build of ParaView and PV3FoamReader" 5 70
  fi
  if [ "$version" == "8.04" ]; then
    if [ "x$BUILD_PARAVIEW" != "Yes" -o "x$BUILD_QT" != "xYes" ]; then
      BUILD_QT=Yes
      BUILD_PARAVIEW=Yes
      dialog --sleep 6 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
      --title "Non-optional setting detected!" \
      --infobox "You are running Ubuntu $version. \nFor ParaView to work properly this script must do a custom build of Qt and also build ParaView." 5 70
    fi
  fi
  if [ "x$INSTALLMODE" == "xserver" ]; then
      BUILD_PARAVIEW=Yes
      BUILD_PARAVIEW_WITH_GUI=No
      BUILD_PARAVIEW_WITH_MPI=Yes
      dialog --sleep 6 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
      --title "Server Install settings" \
      --infobox "Installer in server install mode. \n ParaView will be build without GUI and with MPI support" 5 70  
  fi

  #verifying ParaView Build options, just in case
  if [ "x$BUILD_PARAVIEW" == "xNo" ]; then
    if [ "x$BUILD_PARAVIEW_WITH_MPI" == "xYes" -o "x$BUILD_PARAVIEW_WITH_PYTHON" == "xYes" -o \
        "x$BUILD_PARAVIEW_WITH_GUI" == "xNo" -o "x$BUILD_QT" == "xYes" ]; then
        BUILD_PARAVIEW=Yes
        dialog --sleep 6 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
        --title "Non-optional setting detected!" \
        --infobox "\nParaView will need to be built, since the pre-built version isn't enough for the chosen options." 10 70
    fi
  fi

  if [ "x$BUILD_PARAVIEW" == "xYes" -a "x$BUILD_PARAVIEW_WITH_MPI" == "xNo" -a \
       "x$BUILD_PARAVIEW_WITH_GUI" == "xNo" ]; then
      BUILD_PARAVIEW_WITH_MPI=Yes
      dialog --sleep 6 --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"   \
      --title "Bad options detected!" \
      --infobox "\nParaView must be built with either MPI or GUI. Since you've defined both Off, will assume server mode and turn on MPI." 10 70
  fi

  #GCC compiling settings
  if [ "x$USE_OF_GCC" == "xYes" ]; then
    if [ "$arch" == "x86_64" ]; then
      while : ; do
        GCCSETTINGSOPTS=$(dialog --stdout --separate-output \
        --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
        --checklist "Choose Install settings: < Space to select ! >" 10 60 2 \
        1 "Build GCC? (otherwise use pre-compiled version)" off \
        2 "Build GCC in 64bit mode only?" off )
        
        if [ x"$?" == x"0" ]; then
          break;
        else
          cancel_installer
        fi
      done

    elif [ x`echo $arch | grep -e "i.86"` != "x" ]; then
      while : ; do  
        GCCSETTINGSOPTS=$(dialog --stdout --separate-output \
        --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu"         \
        --checklist "Choose Install settings: < Space to select ! >" 10 60 1 \
        1 "Build GCC? (otherwise use pre-compiled version)" off )
        
        if [ x"$?" == x"0" ]; then
          break;
        else
          cancel_installer
        fi
      done
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
  while : ; do
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
    
    if [ x"$?" == x"0" ]; then
      break;
    else
      cancel_installer
    fi
  done

  #Detect and take care of fastest mirror
  if [ "x$mirror" == "xfindClosest" ]; then
    clear

    (
      echo "Searching for the closest mirror..."
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
    mirror_total_count=10   # it already includes the mirror picked line!
    mirror_initial_line_count=5
    percent=0
    (
    while [ "x$mirror" == "x" ] ; do
      mirror=`grep "picked:" tempmirror.log | cut -c20-`
      percent=`cat tempmirror.log | wc -l`
      percent=`expr \( $percent - $mirror_initial_line_count \) \* 100 / $mirror_total_count`
      echo $percent
      echo "XXX"
      echo -e "`cat tempmirror.log`"
      echo "XXX"
      sleep 1
    done
    ) | dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
        --title "Mirror selector" --gauge "Starting..." 20 60 $percent
    
    # due to the sub-shell execution, have to get again the mirror's name
    mirror=`grep "picked:" tempmirror.log | cut -c20-`
    rm -f tempmirror.log
  fi
  clear

  #Show to user the detected settings, last chance to cancel the installer
  while : ; do
    (dialog --backtitle "OpenFOAM-1.6.x Installer for Ubuntu - code.google.com/p/openfoam-ubuntu" \
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
!For more info see documentation on code.google.com/p/openfoam-ubuntu" 15 80)
    
    if [ x"$?" == x"0" ]; then
      break;
    else
      cancel_installer
    fi
  done

else

  #Enable this script's logging functionality ...
  if [ "$LOG_OUTPUTS" == "Yes" ]; then
    exec 2>&1 > >(tee -a installOF.log)
    LOG_OUTPUTS_FILE_LOCATION=$PWD/installOF.log
  fi

fi
#END OF INTERACTIVE SECTION  ----------------------------------

#have to save a list of the running PIDs, to avoid killing them in the future!
save_running_pids

#Run usual install steps if in "fresh" or "server" install mode
#If not, skip to the last few lines of the script
if [ "x$INSTALLMODE" != "xupdate" ]; then

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
    if [ "x$FOAMINSTALLFAILED" == "x" -o "x$FOAMINSTALLFAILED_BUTCONT" == "xYes" ]; then
      
      #build Qt
      build_Qt
      
      #build ParaView
      build_ParaView
      
      #build the PV3FoamReader plugin
      build_PV3FoamReader
      
      #build ccm26ToFoam
      build_ccm26ToFoam
      
    fi
  fi

  #final messages and instructions
  final_messages_for_clean_install

fi

if [ "x$INSTALLMODE" == "xupdate" ]; then

  #Activate OpenFOAM environment
  setOpenFOAMEnv

  #do a git pull
  OpenFOAM_git_pull

  #do an Allwmake on OpenFOAM 1.6.x
  allwmake_openfoam

fi

set +e

if [ "x$FOAMINSTALLFAILED" == "x" -o "x$FOAMINSTALLFAILED_BUTCONT" == "xYes" ]; then
  # NOTE: run bash instead of exit, so the OpenFOAM environment stays operational on 
  #the calling terminal.
  cd_openfoam
  #calling bash from here seems to be a bad idea... doesn't seem to work properly...
  #bash
else
  #this shouldn't be necessary, but just in case:
  exit
fi
