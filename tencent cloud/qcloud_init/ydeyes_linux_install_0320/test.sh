#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
dir=$(dirname $(which $0))
script=`basename $0`

check_os_type()
{
# ostype: tlinux|SuSE|centos|redhat|ubuntu|debian|windows
for os in tlinux centos redhat SuSE;do [ -f /etc/${os}-release ] && echo ${os} && return; done
for os in ubuntu debian;do grep ^ID=${os}$ /etc/os-release >/dev/null 2>/dev/null && echo ${os} && return; done
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

status=`ps ax | grep "YDService" | grep -v "grep" |wc -l`
if [ $status -eq 0 ]; then
    err="failed"
    r="${r}{\"filePath\":\"YDService\",\"failReason\":\"YDService process not exist\"},"
    e=1
fi

status=`ps ax | grep "YDLive" | grep -v "grep" |wc -l`
if [ $status -eq 0 ]; then
    err="failed"
    r="${r}{\"filePath\":\"YDLive\",\"failReason\":\"YDLive process not exist\"},"
    e=1
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
  local ip=`/sbin/ifconfig eth0|grep addr:|awk '{print $2}'|sed 's/addr://'`
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

