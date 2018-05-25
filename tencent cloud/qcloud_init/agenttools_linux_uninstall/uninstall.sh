#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
dir=$(dirname $(which $0))
script=`basename $0`

check_os_type()
{
    # ostype: tlinux|SuSE|centos|redhat|ubuntu|debian|windows
    for os in tlinux centos redhat SuSE;do
        [ -f /etc/${os}-release ] && echo ${os} && return;
    done
    for os in ubuntu debian;do
        grep ^ID=${os}$ /etc/os-release >/dev/null 2>/dev/null && echo ${os} && return;
    done
    grep -i =ubuntu /etc/lsb-release >/dev/null 2>/dev/null && echo ubuntu
}

ostype=`check_os_type`
if [ ${ostype} = 'ubuntu' -o ${ostype} = 'debian' ]; then
    file=/etc/rc.local
else
    file=/etc/rc.d/rc.local
fi

killall -9 agent 2> /dev/null
killall -9 agentPlugInD 2> /dev/null
killall -9 base 2> /dev/null
killall -9 tcvmstat 2> /dev/null
killall -9 sysddd 2> /dev/null

killall -9 agent 2> /dev/null
rm -f /usr/local/agenttools/agent/cache_warning
killall -9 agentPlugInD 2> /dev/null
killall -9 base 2> /dev/null
killall -9 tcvmstat 2> /dev/null
killall -9 sysddd 2> /dev/null
if [ -d /usr/local/agenttools ]
then
    rm -rf /usr/local/agenttools
fi

sed -i '/agenttools/d' $file
crontab -l|grep -v agenttools >/tmp/cronfile
crontab /tmp/cronfile
rm -rf /tmp/cronfile

echo AGENTTOOLS uninstall success

