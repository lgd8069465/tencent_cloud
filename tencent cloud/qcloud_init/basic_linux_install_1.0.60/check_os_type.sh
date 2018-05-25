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
  for os in ubuntu debian;do grep ^ID=${os}$ /etc/os-release >/dev/null 2>/dev/null && echo ${os} && return; done
  grep -i =ubuntu /etc/lsb-release >/dev/null 2>/dev/null && echo ubuntu
}
