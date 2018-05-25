#!/bin/bash
# Copyright (C) 2017 Tencent.com
#
# This file is part of TencentCloud. It is used to assist with the following features:
# 1. config_set_passwords
# 2. config_ssh_pub_key
# 3. config_network

RETVAL=0

cdrom_label="config-2"
cloud_init="/usr/bin/cloud-init"
last_action_dir="/usr/local/qcloud/action/"

log_output() {
    echo "[`date "+%Y-%m-%d %H:%M:%S"`]:${1}"
}

_exit() {
    umount $mount_dir
    rm -rf $mount_dir
    rm -rf /run/cloud-init/.instance-id
    exit $RETVAL
}

config_set_passwords() {
    log_output "config_set_passwords, begin"
    rm -rf /var/lib/cloud/instance/sem/config_set_passwords
    $cloud_init single --n set-passwords
    RETVAL=$?
    log_output "config_set_passwords return value ${RETVAL}, end"
    return $RETVAL
}

config_set_hostname() {
    log_output "config_set_hostname, begin"
    rm -rf /var/lib/cloud/instance/sem/config_set_hostname
    $cloud_init single --n set_hostname
    hostnamectl --transient set-hostname $hostname &
    hostnamectl --static set-hostname $hostname &
    hostnamectl --pretty set-hostname $hostname &
    RETVAL=$?
    log_output "config_set_hostname return value ${RETVAL}, end"
    return $RETVAL
}

config_network() {
    log_output "config_network, begin"
    ifconfig eth0 $eth0_ip_addr netmask $eth0_netmask
    route add default gw $eth0_gateway
    config_set_hostname
    rm -f /var/lib/cloud/data/instance-id
    $cloud_init init --local
    RETVAL=$?
    log_output "config_network return value ${RETVAL}, end"
}

config_users_groups() {
    log_output "config_users_groups, begin"
    rm -rf /var/lib/cloud/instance/sem/config_users_groups
    $cloud_init single --n users-groups
    RETVAL=$?
    log_output "config_users_groups return value ${RETVAL}, end"
    return $RETVAL
}

config_ssh_pub_key() {
    log_output "config_ssh_pub_key, begin"
    if [ "$username" == "root" ]; then
        ssh_key_file='/root/.ssh/authorized_keys'
    else
        ssh_key_file=/home/${username}/.ssh/authorized_keys
    fi
    rm -f $ssh_key_file
    config_users_groups
    config_set_passwords
    RETVAL=$?
    log_output "config_ssh_pub_key return value ${RETVAL}, end"
    return $RETVAL
}

load_action_conf() {
    dev=$(blkid -tLABEL=$cdrom_label -odevice)
    mount_dir=$(mktemp -d /tmp/tmp.XXXXXX)
    action_file="${mount_dir}""${qcloud_action_file}"
    mount $dev $mount_dir
    if [ -f $action_file ]; then
        . $action_file
        RETVAL=0
    else
        RETVAL=1
    fi
    umount $mount_dir
    rm -rf $mount_dir
    return $RETVAL
}


rm -rf /run/cloud-init/.instance-id
dev=$(blkid -tLABEL=$cdrom_label -odevice)
if [ -z '$dev' ]; then
    dev='/dev/sr0'
fi
mount_dir=$(mktemp -d /tmp/tmp.XXXXXX)
mount $dev $mount_dir

qcloud_action_dir=${mount_dir}/qcloud_action
for action_conf in ${qcloud_action_dir}/*.conf
do
    if [ `basename $action_conf` == "os.conf" ]; then
        continue
    fi
    . $action_conf
    if [ $? -ne 0 ] ; then
        log_output "load ${action_conf} failed."
        continue
    fi
    last_action_file=${last_action_dir}/$action
    last_action_timestamp=`cat $last_action_file`
    current_action_timestamp=$timestamp
    if [ "$last_action_timestamp" == "$current_action_timestamp" ];then
        continue
    fi

    case "$action" in
        config_set_passwords)
            config_set_passwords
            RETVAL=$?
            ;;
        config_ssh_pub_key)
            config_ssh_pub_key
            RETVAL=$?
            ;;
        config_network)
            config_network
            RETVAL=$?
            ;;
        *)
            log_output "${action} not found."
            RETVAL=3
            ;;
    esac

    if [ $RETVAL -eq 0 ] ; then
        mkdir -p $last_action_dir
        echo $current_action_timestamp > $last_action_file
    fi
done
_exit
