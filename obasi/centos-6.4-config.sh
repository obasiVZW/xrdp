#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo -n "Enter username for xrdp :"
read username
home_dir=`su ${username} -c 'echo $HOME'`

#Make sure there is no DISPLAY environment variable defined
display=`cat ${home_dir}/.bashrc | grep -i DISPLAY`

if [[ -n "${display}" ]]; then
	echo 'Remove display environment variable from  ${home_dir}/.bashrc' 1>&2
	exit 1
fi

display=`cat ${home_dir}/.bash_profile | grep -i DISPLAY`

if [[ -n "${display}" ]]; then
	echo 'Remove display environment variable from  ${home_dir}/.bash_profile' 1>&2
	exit 1
fi

#Stop NX
/sbin/chkconfig freenx-server off &> /dev/null
/etc/init.d/freenx-server stop &> /dev/null

#Install/Update EPEL & RPMforge
rpm -Uvh http://packages.sw.be/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

#Install needed Packages
yum install -y tigervnc-server autoconf automake libtool openssl-devel pam-devel libX11-devel libXfixes-devel gcc libXrandr-devel.x86_64

# go to <someplace>/xrdp/obasi/
cd $(dirname $0)
# go to <someplace>/
cd ./../../

cp -rf xrdp /usr/lib64/xrdp-v0.8-obasi
cd /usr/lib64/xrdp-v0.8-obasi

#Now to install updated version of XRDP
./bootstrap
./configure
make
make install

#Generate custom rsakeys.ini
/usr/local/bin/xrdp-keygen xrdp auto

#Configure session manager
sed -i "s/AllowRootLogin=1/AllowRootLogin=0/g" /etc/xrdp/sesman.ini
sed -i "s/AssignSessionByUsername=0/AssignSessionByUsername=1/g" /etc/xrdp/sesman.ini

#Setup Users Groups
groupadd tsusers
groupadd tsadmins

#Add users to groups
usermod -G tsusers ${username}
usermod -G tsadmins root

#Edit the VNC Server
echo "VNCSERVERS=\"1:${username}\"" >> /etc/sysconfig/vncservers
echo "VNCSERVERARGS[1]=\"-geometry 1024x768 -depth 16\"" >> /etc/sysconfig/vncservers

#Run VNC server to create xstartup script
clear
echo "Staring Xvnc, please enter ${username}'s password below :"
/sbin/service vncserver start

#Now to hook XRDP Server to the rc.local file
echo '/etc/xrdp/xrdp.sh start' >> /etc/rc.local

#Copy keyboard settings
cp /usr/lib64/xrdp-v0.8-obasi/instfiles/km-0813.ini /etc/xrdp/

#Replace xrdp.ini with obasi implementation
cp -f /usr/lib64/xrdp-v0.8-obasi/obasi/xrdp.ini /etc/xrdp/xrdp.ini

#Turn on the services
/sbin/chkconfig vncserver on
/etc/xrdp/xrdp.sh start

#Turn off terminal bell
sed -i "s/#set bell-style none/set bell-style none/g" /etc/inputrc

#Add display export to frmxml2f.sh for application servers
frmxml2f=`find ${home_dir} -iname "frmxml2f.sh" | grep -i asinst_1`

if [[ -n "${frmxml2f}" ]]; then
	display=`cat ${frmxml2f} | grep -i 'export DISPLAY'`

	if [[ -z "${display}" ]]; then
		sed -i '2i\export DISPLAY=:1.0' ${frmxml2f}
	fi
fi
