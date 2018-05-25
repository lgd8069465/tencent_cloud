#!/bin/sh

umask 0022
unset IFS
unset OFS
unset LD_PRELOAD
unset LD_LIBRARY_PATH
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

# step 0, initialization
DIR="$( cd "$( dirname $0 )" && pwd )"
if [ -w '/usr' ]; then
    myPath="/usr/local/qcloud"
else
    myPath="/var/lib/qcloud"
fi
BIT=`getconf LONG_BIT`

if [ "root" != "`whoami`" ]; then
    echo "Only root can execute this script"
    exit 111
fi    

if [ ! -e "$myPath" ]; then
    mkdir -p "$myPath"
fi    

# step 1, install YunJing
cd $DIR
tar -xzf "ydeyes_linux${BIT}.tar.gz"
sh "self_cloud_install_linux${BIT}.sh"


exit 0
