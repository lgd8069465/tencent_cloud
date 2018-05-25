#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
dir=$(dirname $(which $0))
script=`basename $0`

check_os_type()
{
  # ostype: tlinux|suse|centos|redhat|ubuntu|debian
  while [ true ];do
    if [ -f /etc/tlinux-release ];then
      echo tlinux
    return
    fi
    if [ -f /etc/SuSE-release ];then
      echo suse
      return
    fi
    if [ -f /etc/centos-release ];then
      echo centos
    return
    fi
    #centos5 and redhat5
    if [ -f /etc/redhat-release ];then
      grep "Red Hat" /etc/redhat-release >/dev/null
      if [ $? -eq 0 ];then
        echo redhat
        return
      fi
      grep CentOS /etc/redhat-release >/dev/null
      if [ $? -eq 0 ];then
        echo centos
        return
      fi
    fi
    break
  done
  for os in ubuntu debian coreos;do grep ^ID=${os}$ /etc/os-release >/dev/null 2>/dev/null && echo ${os} && return; done
  grep -i =ubuntu /etc/lsb-release >/dev/null 2>/dev/null && echo ubuntu
}

if [ $# -gt 0 ];then
  defined_idc=$1
fi

check_idc_name()
{
  echo ${defined_idc}
}

ostype=`check_os_type`
arch=`getconf LONG_BIT`
idc=`check_idc_name`
if [ -z "${idc}" -o -z "${ostype}" ];then
  echo "os|idc"
  exit 1  
fi

e=0
err=
r=

write_nameserver_profile()
{
    echo "
# nameserver list
gz 10.138.224.65 10.182.20.26 10.182.24.12
st 10.139.224.25 10.154.43.26 10.154.43.37
tj 10.172.94.26  10.172.144.181 10.172.249.182
sh 10.236.158.106 10.237.148.54 10.237.148.60
hk 10.243.28.52 10.145.0.57 10.145.0.58
gzvpc 183.60.83.19 183.60.82.98
shvpc 183.60.83.19 183.60.82.98
ca 10.116.43.132 10.116.43.133
cavpc 183.60.83.19 183.60.82.98
" | grep -w ${idc} | sed "s/${idc}//" | awk '{for(i=1;i<=NF;i++)print "nameserver "$i;print "options timeout:1 rotate"}' >$1
}

#
# config nameserver
#
if [ ${ostype} = 'ubuntu' -a -d /etc/resolvconf ]; then
  #clear old
  if [ -f /etc/resolvconf/resolv.conf.d/head ];then
    rm -f /etc/resolvconf/resolv.conf.d/head >>/dev/null
    touch /etc/resolvconf/resolv.conf.d/head
    file=/etc/resolvconf/resolv.conf.d/base
  fi
else
  file=/etc/resolv.conf
fi


#update
#myfile=${dir}/_dns.txt
#write_nameserver_profile ${myfile}
#diff ${file} ${myfile} >/dev/null
#grep `head -n 1 ${myfile} | awk '{print $2}'` ${file} >/dev/null
#if [ $? -ne 0 ];then
#  err="failed"
#  r="${r}{\"filePath\":\"dns\",\"failReason\":\"config error\"},"
#  e=1
#fi

if [ "$ostype" != "coreos" ];then
  crontab -l|grep ntpdate>/dev/null
  if [ $? -ne 0 ];then
    err="failed"
    r="${r}{\"filePath\":\"ntpdate\",\"failReason\":\"crontab error\"},"
    e=1
  fi
fi

report()
{
  local file=${dir}/_post.txt
  [ -f ${file} ] && rm -rf ${file}
  #__timestamp__
  #__uuid__
  #__ip__
  #__status__,
  #__log__
  #__result__
  local timestamp=`date +'%s'`
  local uuid=`awk '{print $3}' /etc/uuid`
IFCONFIG=`which ifconfig`
  local ip=`${IFCONFIG} eth0|grep addr:|awk '{print $2}'|sed 's/addr://'`
  local status=$e
  local log=$err
  local result=`echo $r|sed 's/,$//'`
  sed -e "s/__timestamp__/${timestamp}/"\
 -e "s/__uuid__/${uuid}/"\
 -e "s/__ip__/${ip}/"\
 -e "s/__status__/${status}/"\
 -e "s/__log__/${log}/"\
 -e "s/__result__/${result}/"\
 ${dir}/post.txt > ${file}
  #curl http://img.atlas.oa.com/api -d @${file}
  wget http://img.atlas.oa.com/api --post-file=${file}
  #rm -rf ${file}
}

report
echo "done"

