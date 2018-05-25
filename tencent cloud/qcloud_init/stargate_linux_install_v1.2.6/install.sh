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
    pythonPath="/usr/local/qcloud/monitor"
else
    myPath="/var/lib/qcloud"
    pythonPath="/var/lib/qcloud/monitor"
fi
agentPath="$myPath/stargate"
agent_name="$agentPath/sgagent"
BIT=`getconf LONG_BIT`

if [ "root" != "`whoami`" ]; then
    echo "Only root can execute this script"
    exit 111
fi    

if [ ! -e "$myPath" ]; then
    mkdir -p "$myPath"
fi    

if [ ! -e "$pythonPath" ]; then
    mkdir -p "$pythonPath"
fi    

# step 1, stop stargate if exist
echo "stop stargate if exist"
if [ -e "$agentPath" ]; then
    if [ -e '/usr/share/coreos/lsb-release' ]; then
        systemctl stop stargate.service
        systemctl disable stargate.service
        rm -f /etc/systemd/system/stargate.*
    else
        $agentPath/admin/delcrontab.sh
        if [ $? -ne 0 ];then
            line="$agentPath/admin/start.sh"
            (crontab -u root -l | grep -v "$line") | crontab -u root -
        fi
    fi

    $agentPath/admin/stop.sh
    if [ $? -ne 0 ];then
        kill -9 `ps aux | grep "$agent_name" | grep -v "grep"| awk '{print $2}'`
        killall -9 $agent_name  > /dev/null 2>&1
    fi
fi    

# step 2, install stargate
cd $DIR
echo "install stargate"
tar -xvzf "stargate.tgz" -C "$myPath"
ln -svf ${agent_name}${BIT} $agent_name
echo "install success"

# step 2.1 install python
echo "install python"
rm -rf "$pythonPath/python26"
cp -r python26-${BIT} "$pythonPath/python26"
chmod +x "$pythonPath/python26/bin/python"

# step 3, reset state
echo "reset state"
$agent_name -r

# step 4, restart stargate
echo "start sgagent"
if [ -e '/usr/share/coreos/lsb-release' ]; then
    cp ./systemd/* /etc/systemd/system/
    cd /etc/systemd/system
    systemctl enable stargate.service
    systemctl start stargate.service
else
    cd "$agentPath/admin"
    ./addcrontab.sh
    ./start.sh
fi

echo "finish"
exit 0
