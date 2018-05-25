#!/bin/bash


dir=$(cd `dirname $0`;pwd)
log_file="/tmp/gpu_init.log"
flag_file="/tmp/gpu_inited"
[  ! -L log -a ! -d log  ] && mkdir log
log()
{
    echo `date` ">>" "$*" >> $log_file
}

is_gpu_host()
{
    gpu_info=$(lspci |grep NVIDIA)
    if [ ${#gpu_info} -gt 0 ];then
        log "nvidia gpu host"
        return 1
    fi

    return 0
}

is_support_os()
{
    if [ -f "/etc/redhat-release" ]; then
        version=$(cat /etc/redhat-release |grep 'CentOS Linux release 7.3' 2>&1)
        if [ $? -eq 0 ];then
            return 1
        fi

        version=$(cat /etc/redhat-release |grep 'CentOS Linux release 7.2' 2>&1)
        if [ $? -eq 0 ];then
            return 1
        fi
    fi

    return 0
}

is_gpu_driver_installed()
{
    driver_info=$(lsmod |grep nvidia)
    if [ ${#driver_info} -gt 0 ];then
        return 1
    fi
    
    return 0
}

test_and_set_first_time_install_flag()
{
    if [ -f "$flag_file" ]; then
        return 1
    fi

    $(echo "gpu environment inited" >$flag_file)
    return 0
}

install_gcc()
{
    #centos
    $(yum install gcc -y)
}

cleanup_gpu_driver()
{
    if [ -f "/gpu_driver.run" ]; then
        $(rm -f /gpu_driver.run)
    fi
}

install_gpu_driver()
{
    $(wget http://mirrors.tencentyun.com/install/linux/nvidia-linux-driver.run -O /gpu_driver.run)
    if [ $? -ne 0 ];then
        log "download driver failed"
        return 0
    fi

    if [ ! -f "/gpu_driver.run" ]; then
        log "driver file does not exist"
        return 0
    fi

    $(chmod +x /gpu_driver.run)

    $(/gpu_driver.run -s)

    driver_info=$(lsmod |grep nvidia 2>&1)
    if [ ${#driver_info} -gt 0 ];then
        return 1
    else
        log "gpu driver install or load failed"
    fi

    return 0
}

config_gpu_environment()
{
    tmpfile='./tmp_gpu_config'

    grep 'nvidia-smi -pm 1' /etc/rc.local >& /dev/null
    if [ "$?" != "0" ];then
        grep -v 'nvidia-smi -pm 1' /etc/rc.local > $tmpfile
        echo 'nvidia-smi -pm 1' >> $tmpfile
        mv $tmpfile /etc/rc.d/rc.local
    fi

    grep 'sysctl kernel.numa_balancing=0' /etc/rc.local >& /dev/null
    if [ "$?" != "0" ];then
        grep -v 'sysctl kernel.numa_balancing=0' /etc/rc.local > $tmpfile
        echo 'sysctl kernel.numa_balancing=0' >> $tmpfile
        mv $tmpfile /etc/rc.d/rc.local
    fi

    grep 'echo never >/sys/kernel/mm/transparent_hugepage/enabled' /etc/rc.local >& /dev/null
    if [ "$?" != "0" ];then
        grep -v 'echo never >/sys/kernel/mm/transparent_hugepage/enabled' /etc/rc.local > $tmpfile
        echo 'echo never >/sys/kernel/mm/transparent_hugepage/enabled' >> $tmpfile
        mv $tmpfile /etc/rc.d/rc.local
    fi

    grep 'echo never >/sys/kernel/mm/transparent_hugepage/defrag' /etc/rc.local >& /dev/null
    if [ "$?" != "0" ];then
        grep -v 'echo never >/sys/kernel/mm/transparent_hugepage/defrag' /etc/rc.local > $tmpfile
        echo 'echo never >/sys/kernel/mm/transparent_hugepage/defrag' >> $tmpfile
        mv $tmpfile /etc/rc.d/rc.local
    fi

    $(chmod +x /etc/rc.d/rc.local)
}


log "start init gpu host environment"

is_support_os
if [ $? -eq 0 ];then
    log "not support os"
    exit 0
fi

is_gpu_host
if [ $? -eq 0 ];then
    log "not gpu host"
    exit 0
fi

is_gpu_driver_installed
if [ $? -eq 1 ];then
    log "gpu driver aleady installed"
    exit 0
fi

test_and_set_first_time_install_flag
if [ $? -eq 1 ];then
    log "gpu environment inited, no more try"
    exit 0
fi

# wait for network
sleep 10

install_gcc
log "install gcc done"

install_gpu_driver
if [ $? -eq 1 ];then
    log "gpu driver install success"
    $(nvidia-smi -pm 1)
else
    log "gpu driver install failed"
fi

cleanup_gpu_driver

config_gpu_environment

log "finish init gpu host environment"