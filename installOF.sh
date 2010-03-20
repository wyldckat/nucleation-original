#!/bin/bash
#
#
# USAGE: ./installOF
#
#
# Created by Mads Reck (madstmp (a-t) gmail.com)
# with kind help (testning and revision) from Anton Kidess, Bruno Santos and Fabio C. Canesin (fc at canesin dot com)

set -e
arch=`uname -m`
version=`uname -r`  
version=`cat /etc/lsb-release | grep DISTRIB_RELEASE= | sed s/DISTRIB_RELEASE=/$1/g`
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
echo "10 - EXIT INSTALL"
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
10) exit;;
esac 

echo "------------------------------------------------------"
echo " Your system appears to be "$arch" Acting accordingly "
echo "------------------------------------------------------"
echo "Making sure that you have all needed libraries"
echo "------------------------------------------------------"
echo "Apparently we need to run apt-get multiple times to   "
echo " be SURE that everything is installed                 "
echo "------------------------------------------------------"
echo "--Installing dependencies ----------------------------"
echo "------------------------------------------------------"
sudo apt-get update -y -q=2
sudo apt-get upgrade -y -q=2
sudo apt-get install -y -q=2 binutils-dev flex git git-core build-essential python-dev libqt4-dev libreadline5-dev wget zlib1g-dev cmake
echo "------------------------------------------------------"
echo "Downloading ThirdParty stuff"
echo "------------------------------------------------------"
cd ~
mkdir OpenFOAM
cd OpenFOAM
echo "Your system appears to be Ubuntu "$version". Acting accordingly"
echo "------------------------------------------------------"
if [ "$arch" == "x86_64" ]; then
wget http://downloads.sourceforge.net/foam/ThirdParty-1.6.General.gtgz?use_mirror=$mirror
wget http://downloads.sourceforge.net/foam/ThirdParty-1.6.linux64Gcc.gtgz?use_mirror=$mirror
echo "------------------------------------------------------"
echo "Untarring - this takes a while..."
echo "------------------------------------------------------"
tar xfz ThirdParty-1.6.General.gtgz 
tar xfz ThirdParty-1.6.linux64Gcc.gtgz
echo "------------------------------------------------------"
if [ "$version" == "9.10" ]; then
echo "-----------------------------------------------------"
cd ~/OpenFOAM/ThirdParty-1.6/gcc-4.3.3/platforms/linux64/lib64
mv libstdc++.so.6 libstdc++.so.6.orig
ln -s `locate libstdc++.so.6.0 | grep "^/usr/lib" | head -n 1` libstdc++.so.6
mv libgcc_s.so.1 libgcc_s.so.1.orig
ln -s `locate libgcc_s.so. | grep "^/lib" | head -n 1` libgcc_s.so.1
cd ~/OpenFOAM
echo "Fix up done"
echo "------------------------------------------------------"
fi
echo "------------------------------------------------------"
echo "Retrieveing OpenFOAM..."
echo "------------------------------------------------------"
ln -s  ~/OpenFOAM/ThirdParty-1.6 ~/OpenFOAM/ThirdParty-1.6.x
git clone http://repo.or.cz/r/OpenFOAM-1.6.x.git
cd OpenFOAM-1.6.x/
. ~/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc 
echo . ~/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc >> ~/.bashrc
echo "------------------------------------------------------"
echo "Compiling OpenFOAM...output is in make.log"
echo " THIS CAN TAKE HOURS"
echo "------------------------------------------------------"
 ./Allwmake >make.log 2>&1
fi
if [ "$arch" == "i386" ]; then
wget http://downloads.sourceforge.net/foam/ThirdParty-1.6.General.gtgz?use_mirror=$mirror
wget http://downloads.sourceforge.net/foam/ThirdParty-1.6.linuxGcc.gtgz?use_mirror=$mirror
echo "------------------------------------------------------"
echo "Untarring - this takes a while..."
echo "------------------------------------------------------"
tar xfz ThirdParty-1.6.General.gtgz 
tar xfz ThirdParty-1.6.linuxGcc.gtgz
if [ "$version" == "9.10" ]; then
echo "-----------------------------------------------------"
cd ~/OpenFOAM/ThirdParty-1.6/gcc-4.3.3/platforms/linux64/lib64
mv libstdc++.so.6 libstdc++.so.6.orig
ln -s `locate libstdc++.so.6.0 | grep "^/usr/lib" | head -n 1` libstdc++.so.6
mv libgcc_s.so.1 libgcc_s.so.1.orig
ln -s `locate libgcc_s.so. | grep "^/lib" | head -n 1` libgcc_s.so.1
cd ~/OpenFOAM
echo "Fix up done"
echo "------------------------------------------------------"
fi
echo "Retrieveing OpenFOAM..."
echo "------------------------------------------------------"
ln -s  ~/OpenFOAM/ThirdParty-1.6 ~/OpenFOAM/ThirdParty-1.6.x
git clone http://repo.or.cz/r/OpenFOAM-1.6.x.git
cd OpenFOAM-1.6.x/
. ~/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc 
echo . ~/OpenFOAM/OpenFOAM-1.6.x/etc/bashrc >> ~/.bashrc
echo "------------------------------------------------------"
echo "Compiling OpenFOAM...output is in make.log"
echo " THIS CAN TAKE HOURS"
echo "------------------------------------------------------"
 ./Allwmake >make.log 2>&1
fi
echo "------------------------------------------------------"
echo "Checking installation - you should see NO criticals..."
echo "------------------------------------------------------"
foamInstallationTest
set +e
set -e
echo "------------------------------------------------------"
echo "Fixing call for bash in tutorials (default is dash in Ubuntu-9)"
for file in `find ~/OpenFOAM/OpenFOAM-1.6.x/tutorials/ -name All*`; do
mv $file $file.old
sed '/^#!/ s/\/bin\/sh/\/bin\/bash/' $file.old > $file
rm -f $file.old
done
echo "Fix up bash done"
echo "------------------------------------------------------"
set +e
