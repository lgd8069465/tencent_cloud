#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
dir=$(cd `dirname $0`;pwd)
script=`basename $0`

#======================================================================
#				     	 Basic Work
#----------------------------------------------------------------------
check_os_type()
{
  # ostype: tlinux|opensuse|suse|centos|redhat|ubuntu|debian
  while [ true ];do
    if [ -f /etc/tlinux-release ];then
      echo tlinux
    return
    fi
    if [ -f /etc/SuSE-release ];then
		grep -i "opensuse" /etc/SuSE-release >/dev/null 2>/dev/null && echo "opensuse" || echo "suse"
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
  grep -i =ubuntu /etc/lsb-release >/dev/null 2>/dev/null && echo ubuntu && return
  [ -f /etc/freebsd-update.conf ] && echo FreeBSD
}

# get centos or redhat os version such as 5,6,7
get_redhat_centos_ver()
{
	if [ -f /etc/centos-release ]; then
		echo `sed 's/^.*release \([0-9]\).*$/\1/' /etc/centos-release`
	elif [ -f /etc/redhat-release ]; then
		echo `sed 's/^.*release \([0-9]\).*$/\1/' /etc/redhat-release`
	fi
}

# get redhat and centos os whole version info,such as 6.8,7.3
get_redhat_centos_whole_version()
{
    if [ -f /etc/centos-release ];then
        ver=`grep -o "[[:digit:]]\{1,\}\.[[:digit:]]\{1,\}" /etc/centos-release`
    else
        ver=`grep -o "[[:digit:]]\{1,\}\.[[:digit:]]\{1,\}" /etc/redhat-release`
    fi
    echo "$ver"
    return
}

#clear log file and bash_history file
file_clear()
{
	echo "->Cler log file and bash_history......"
	find /var/log -type f|while read f;do echo "">$f ;done
	echo " ">/root/.bash_history
	if [  "$ostype" == "ubuntu"  ];then
		echo " " >/home/ubuntu/.bash_history
	fi
}

function config_sysctl()
{
    local sysctl_key=$1 #sysctl.***
    local tmpfs_key=$2 #such as /proc/***
    local value=$3
    local file
    local tmpfile="./tmp_sysctl_file"
    [ -f /etc/sysctl.conf.first ] && file="/etc/sysctl.conf.first" || file="/etc/sysctl.conf"
    echo "--->config_sysctl:<$file>[$sysctl_key,$tmpfs_key]($value)"

    # write config file
    grep -v "$sysctl_key" $file > $tmpfile
    echo "$sysctl_key = $value" >> $tmpfile
    mv -f $tmpfile $file

    #take effect right now
    echo $value > $tmpfs_key
}

#add a data directory 
function add_data_directory()
{
    [ -d /data ] || mkdir /data
}

function get_rc_local_file()
{
    if [ ${ostype} = 'ubuntu' -o ${ostype} = 'debian' -o ${ostype} = 'FreeBSD' ]; then
        file=/etc/rc.local
    else
        file=/etc/rc.d/rc.local
    fi
    echo "$file"
}

#
# config ntpdate
#
ntpdate_config()
{
    local file=$(get_rc_local_file)
    crontab -l |grep -v ntpupdate > /tmp/cronfile
    cat>> /tmp/cronfile <<EOF
*/20 * * * * /usr/sbin/ntpdate ntpupdate.tencentyun.com >/dev/null &
EOF

    crontab /tmp/cronfile
    rm -rf /tmp/cronfile

    grep '/usr/sbin/ntpdate ntpupdate.tencentyun.com >/dev/null 2>&1 &' ${file} >/dev/null
    if [ $? -ne 0 ];then
        cat>>$file<<EOF
/usr/sbin/ntpdate ntpupdate.tencentyun.com >/dev/null 2>&1 &
EOF
    fi
}

#---------------------------------------------
#config logrotate  
#---------------------------------------------
#config logrotate for redhat and centos
backup_file()
{
  local bak=`date +'%F'`
  local source_dir=$1
  [ -d ${source_dir}/${bak} ] || mkdir ${source_dir}/${bak}
  find ${source_dir} -maxdepth 1 -type f -exec cp -f {} ${source_dir}/${bak}/ \;
}
config_rc_logrotate()
{
	local logrd=/etc/logrotate.d
	local ver=`get_redhat_centos_ver`

	case $ver in
		"5")
			cp -f $dir/redhat-centos-5-syslog $logrd/syslog
			;;
	esac
}
config_logrotate()
{
	case $ostype in
		"centos")
			config_rc_logrotate
			;;
		"redhat")
			config_rc_logrotate
			;;
		"ubuntu")
			local name=`grep ^DISTRIB_CODENAME= /etc/lsb-release |sed 's/.*=//'`
			if [ "${name}" = precise -o "${name}" = lucid  ];then
				sed -i '/weekly/d' /etc/logrotate.d/rsyslog
			fi
			###for history configure for ubuntu 10
			if [  "${name}" = lucid  ];then
				echo " " > /etc/skel/.bash_history
				cp -f /home/ubuntu/.bashrc /etc/skel/.bashrc
			fi
			;;
	esac
}

#---------------------------------------------
# config repos
#---------------------------------------------
backup_reposd()
{
  #local bak=`date +'%F'`
  #local reposd=/etc/yum.repos.d
  #[ -d ${reposd}/${bak} ] || mkdir ${reposd}/${bak}
  #find ${reposd} -maxdepth 1 -type f -exec mv {} ${reposd}/${bak}/ \;
  #local gpg=/etc/pki/rpm-gpg
  #[ -d ${gpg}/${bak} ] || mkdir -p ${gpg}/${bak}
  #find ${gpg} -maxdepth 1 -type f -exec mv {} ${gpg}/${bak}/ \;
  local reposd=/etc/yum.repos.d
  rm $reposd/* -rf
}

backup_apt_sources()
{
  rm -f /etc/apt/sources.list.20*
  #[ -f /etc/apt/sources.list ] && cp /etc/apt/sources.list /etc/apt/sources.list.`date +%F`
}

config_repos_tlinux()
{
  backup_reposd
  local reposd=/etc/yum.repos.d
  cp -f ${dir}/tlinux12_base.repo ${reposd}/base.repo
  cp -f ${dir}/Tencent-tlinux12-Root.crt /etc/pki/tls/certs/Tencent-tlinux-Root.crt
  #cp ${dir}/RPM-GPG-KEY-CentOS-6 /etc/pki/rpm-gpg/
  rpm --import ${dir}/RPM-GPG-KEY-CentOS-6
  #cp ${dir}/tlinux12_epel.repo ${reposd}/epel.repo
  #cp ${dir}/RPM-GPG-KEY-EPEL-6 /etc/pki/rpm-gpg/
  yum clean all >/dev/null
}


config_repos_ubuntu()
{
  backup_apt_sources
  local name=`grep ^DISTRIB_CODENAME= /etc/lsb-release |sed 's/.*=//'`
  if [ "${name}" = precise ];then
    cp -f ${dir}/ubuntu12_sources.list /etc/apt/sources.list
  elif [ "${name}" = lucid ];then
    cp -f ${dir}/ubuntu10_sources.list /etc/apt/sources.list
  elif [ "${name}" = trusty ];then
    cp -f ${dir}/ubuntu14_sources.list /etc/apt/sources.list
  elif [ "${name}" = "xenial" ];then
    cp -f ${dir}/ubuntu16_sources.list /etc/apt/sources.list
  fi
  apt-get clean all >/dev/null 2>&1
  #apt-get update >/dev/null 2>&1
}

config_repos_SUSE10()
{
  zypper sl | 
  grep -v ^# | 
  grep -v ^- | 
  awk '{print $9}' | 
  while read name;do
    zypper sd ${name}
  done
  echo -e "y\n" | \
  zypper sa -t YaST http://mirrors.tencentyun.com/suse/ SuSE
  echo -e "y\n" | \
  zypper sa -t YaST http://mirrors.tencentyun.com/suse/update/ SuSE-update
}

config_repos_SUSE()
{
  local ver=`grep ^VERSION /etc/SuSE-release|awk '{print $3}'|sed 's/\..*$//'`
  if [ $ver -eq 10 ];then
    config_repos_SUSE10
  fi
}

config_repos_openSUSE12()
{
  local dst=/etc/zypp/repos.d
  local bak=$dst/bak`date +%F`
  mkdir -p $bak
  find $dst -maxdepth 1 -type f -exec mv {} $bak/ \;
  ls ./openSUSE12_*|while read f;do 
    cp -f $f $dst/${f##.*openSUSE12_}
  done
  zypper clean >/dev/null 2>&1
  #zypper refs > /dev/null 2>&1
}

config_repos_openSUSE13()
{
  local dst=/etc/zypp/repos.d
  rm $dst/* -rf
  zypper ar http://mirrors.tencentyun.com/opensuse/distribution/13.2/repo/oss/ openSUSE-13.2-Oss
  zypper ar -d http://mirrors.tencentyun.com/opensuse/distribution/13.2/repo/oss/ openSUSE-13.2-Non-Oss
  zypper ar http://mirrors.tencentyun.com/opensuse/update/13.2/ openSUSE-13.2-Update
  zypper ar -d http://mirrors.tencentyun.com/opensuse/update/13.2-non-oss/ openSUSE-13.2-Update-Non-Oss
  zypper clean >/dev/null 2>&1
  #zypper ref > /dev/null 2>&1
}

config_repos_openSUSE()
{
  local ver=`grep ^VERSION /etc/SuSE-release|awk '{print $3}'|sed 's/\..*$//'`
  if [ $ver -eq 12 ];then #just config repos for openSUSE12,openSUSE13 is ok in image
      config_repos_openSUSE12
  elif [ $ver -eq 13 ];then
      config_repos_openSUSE13
  fi
}

config_repos_centos()
{
  backup_reposd
  local reposd=/etc/yum.repos.d
  local ver
  if [ -f /etc/centos-release ];then
    ver=`sed 's/^.*release \([0-9]\).*$/\1/' /etc/centos-release`
    if [ "${ver}" = 7 ];then
      cp -f ${dir}/centos7_base.repo ${reposd}/CentOS-Base.repo
      cp -f ${dir}/centos7_epel.repo ${reposd}/CentOS-Epel.repo
      cp -f ${dir}/RPM-GPG-KEY-CentOS-7 /etc/pki/rpm-gpg/
      cp -f ${dir}/RPM-GPG-KEY-EPEL-7 /etc/pki/rpm-gpg/
      rpm --import ${dir}/RPM-GPG-KEY-CentOS-7
      rpm --import ${dir}/RPM-GPG-KEY-EPEL-7
    elif [ "${ver}" = 6 ];then
      cp -f ${dir}/centos6_base.repo ${reposd}/CentOS-Base.repo
      cp -f ${dir}/centos6_epel.repo ${reposd}/CentOS-Epel.repo
      cp -f ${dir}/RPM-GPG-KEY-CentOS-6 /etc/pki/rpm-gpg/
      cp -f ${dir}/RPM-GPG-KEY-EPEL-6 /etc/pki/rpm-gpg/
      rpm --import ${dir}/RPM-GPG-KEY-CentOS-6
      rpm --import ${dir}/RPM-GPG-KEY-EPEL-6
    fi
  fi

  if [ -f /etc/redhat-release ];then
    ver=`sed 's/^.*release \([0-9]\).*$/\1/' /etc/redhat-release`
    if [ "${ver}" = 5 ];then
      cp -f ${dir}/centos5_base.repo ${reposd}/CentOS-Base.repo
      cp -f ${dir}/centos5_epel.repo ${reposd}/CentOS-Epel.repo
      cp -f ${dir}/RPM-GPG-KEY-CentOS-5 /etc/pki/rpm-gpg/
      cp -f ${dir}/RPM-GPG-KEY-EPEL-5 /etc/pki/rpm-gpg/
      rpm --import ${dir}/RPM-GPG-KEY-CentOS-5
      rpm --import ${dir}/RPM-GPG-KEY-EPEL-5
    fi
  fi
  yum clean all >/dev/null 2>&1
}

get_debian_version() 
{ 
        grep -i "VERSION_ID" "/etc/os-release" >/dev/null 2>/dev/null 
        if [  "$?" == "0"  ];then 
                version=`sed -n 's/VERSION_ID=\"\([0-9]\)\"/\1/p' /etc/os-release` 
                echo $version 
                return 
        elif [  -f /etc/debian_version  ];then 
                version=`sed -n 's/\([0-9]\)\.[0-9].*/\1/p' /etc/debian_version` 
                echo $version 
                return 
        fi  
}

config_repos_debian()
{
	backup_apt_sources
	ver=`get_debian_version`
	case $ver in 
		"7")    
		cp -f ${dir}/debian7_sources.list /etc/apt/sources.list
		;;      
		"8")    
		cp -f ${dir}/debian8_sources.list /etc/apt/sources.list
		;;
		"9")    
		cp -f ${dir}/debian9_sources.list /etc/apt/sources.list
		;;
		"6")
		cp ${dir}/debian6_sources.list /etc/apt/sources.list
		apt-key add ${dir}/debian6_key.asc
		;;      
	esac
    apt-get clean all >/dev/null 2>&1
    #apt-get update >/dev/null 2>&1
}
config_repos_redhat()
{
  #backup_reposd
  #local reposd=/etc/yum.repos.d
  #cp -f ${dir}/redhat5_base.repo ${reposd}/base.repo
  ##cp ${dir}/RPM-GPG-KEY-CentOS-5 /etc/pki/rpm-gpg/
  #rpm --import ${dir}/RPM-GPG-KEY-CentOS-5
  #cp -f ${dir}/redhat5_epel.repo ${reposd}/epel.repo
  ##cp ${dir}/RPM-GPG-KEY-EPEL-5 /etc/pki/rpm-gpg/
  #rpm --import ${dir}/RPM-GPG-KEY-EPEL-5
	rm /etc/yum.repos.d/* -rf
	yum clean all >/dev/null 2>&1
}

config_repos()
{
    local "osinfo"=$1
    echo "->begin config repository for ${osinfo}"
    case ${osinfo} in
        #tlinux)
            #  config_repos_tlinux
            #  ;;
        suse)
            config_repos_SUSE
            ;;
        opensuse)
            config_repos_openSUSE
            ;;
        centos)
            config_repos_centos
            ;;
        ubuntu)
            config_repos_ubuntu
            ;;
        debian)
            config_repos_debian
            ;;
        redhat)
            config_repos_redhat
            ;;
    esac
    echo "->repository config ok..."
}
#------------------------------------------
#fix tty0 and ttyS0 
#------------------------------------------
tty0_and_ttyS0_order_fix()
{
    for f in grub.conf menu.lst ; do
        if [ -f /boot/grub/${f} ];then
            file /boot/grub/${f} | grep ASCII > /dev/null
            if [ $? -eq 0 ];then
                echo "->change ttyS0 order in grub, modify /boot/grub/$f ..."
                sed -i 's/tty0\(.*\)ttyS0/ttyS0\1tty0/' /boot/grub/${f}
            fi
        fi
    done
}


fix_centos6_ttyS0()
{
    [ "$ostype" != "centos" -a "$ostype" != "redhat" -a "$ostype" != "tlinux" ] && return
    local osver=`get_redhat_centos_ver`
    if [ "$osver" == "6" ]; then
        cp -f ${dir}/centos-6-ttyS0 /etc/init/ttyS0.conf 
        ps -ef | grep ttyS0 | grep -v grep &>/dev/null || initctl start ttyS0
    fi
}

#------------------------------------------
acpid_check()
{
    # fix acpid (used for soft shutdown and reboot)
    ps -fe | grep -w "acpid" | grep -v "grep" >/dev/null 2>&1
    if [ $? -ne 0 ];then
        echo "->acpid process is not ok,fix it..."
        case ${ostype} in
            tlinux)
                yum -y install acpid
                service haldaemon stop
                service acpid start
                service haldaemon start
                ;;
            suse)
                zypper --gpg-auto-import-keys -n in acpid
                service acpid start
                ;;
            centos)
                yum -y install acpid
                service haldaemon stop
                service acpid start
                service haldaemon start
                ;;
            ubuntu)
                sudo apt-get -y install acpid
                service acpid start
                ;;
            debian)
                apt-get -y install acpid
                service acpid start
                ;;
            redhat)
                yum -y install acpid
                service haldaemon stop
                service acpid start
                service haldaemon start
                ;;
        esac
        echo "->install acpid ok..."
    else
        echo "->acpid is ok"
    fi
}

get_centos_version_number()
{
	if [ -f /etc/centos-release ]; then
    		version=`sed 's/^.*release \([0-9]\).*$/\1/' /etc/centos-release`
    	elif [ -f /etc/redhat-release ]; then
        	version=`sed 's/^.*release \([0-9]\).*$/\1/' /etc/redhat-release`
    	else
        	version='other'
    	fi  
	echo $version
}


##udev rules for centos 5
generate_udev_centos5_file()
{
	dest_file=/etc/udev/rules.d/45-virtio-disk-qcloud.rules
	echo 'KERNEL=="vd*[!0-9]", SYSFS{serial}=="?*", ENV{ID_SERIAL}="$sysfs{serial}", SYMLINK="disk/by-id/virtio-$env{ID_SERIAL}"' > $dest_file
	echo 'KERNEL=="vd*[0-9]", SYSFS{serial}=="?*", ENV{ID_SERIAL}="$sysfs{serial}", SYMLINK="disk/by-id/virtio-$env{ID_SERIAL}-part%n"' >> $dest_file
}

generate_udevadm_virtio_file()
{
	dest_file=/etc/udev/rules.d/45-virtio-disk-qcloud.rules
	echo 'KERNEL=="vd*[!0-9]",WAIT_FOR="serial"' > $dest_file
	echo 'KERNEL=="vd*[0-9]",WAIT_FOR="../serial"' >> $dest_file
	udevadm control --reload
}

generate_udev_rules()
{
    	case ${ostype} in
		"centos")
			version=`get_centos_version_number`
			if [  "$version" == "5"  ];then
				`generate_udev_centos5_file`
			elif [  "$version" == "6"  ];then
				`generate_udevadm_virtio_file`
			elif [  "$version" == "7" ];then
				`generate_udevadm_virtio_file`
			fi
		;;
		"debian")
			version=`get_debian_version`
			if [  "$version" == "9"  ];then
				`generate_udevadm_virtio_file`
			elif [  "$version" == "8"  ];then
				`generate_udevadm_virtio_file`
			elif [  "$version" == "7"  ];then
				`generate_udevadm_virtio_file`
			fi	
		;;
		"ubuntu")
			local name=`grep ^DISTRIB_CODENAME= /etc/lsb-release |sed 's/.*=//'`
			if [  "${name}" = trusty -o "${name}" = precise -o "$name" = "xenial" ];then
				`generate_udevadm_virtio_file`
			fi
		;;
		"opensuse")
			version=`grep -w VERSION_ID /etc/os-release | sed -n "s/VERSION_ID=\"\(.*\)\"/\1/p"`
			if [  "$version" = "12.3" -o "$version" = "13.2"  ];then
				`generate_udevadm_virtio_file`
			fi
		;;
		"suse")
			version=`grep ^VERSION /etc/SuSE-release|awk '{print $3}'|sed 's/\..*$//'`
			if [  "$version" = "12" -o "$version" = "11"  ];then
				`generate_udevadm_virtio_file`
			fi
		;;
		"tlinux")
			version=`head -1 /etc/issue | awk '{print $4}' 2>/dev/null`
			if [  "$version" = "2.0"  ];then
				`generate_udevadm_virtio_file`
			fi
		;;
		"coreos")
			`generate_udevadm_virtio_file`
		;;
	esac
}

generate_acpipahp_file()
{
	dest_file=/etc/sysconfig/modules/acpiphp.modules
	module_name=/lib/modules/$(uname -r)/kernel/drivers/pci/hotplug/acpiphp.ko
	cat >$dest_file <<EOF
#!/bin/bash
modprobe acpiphp >& /dev/null
EOF
	chmod a+x $dest_file
}

set_acpiphp_boot_load()
{
	case ${ostype} in
		"debian")
			local ver=`get_debian_version`
			if [  "$ver" == "6" ];then
				grep -w acpiphp /etc/modules >/dev/null 2>&1 || echo acpiphp >> /etc/modules
				modprobe acpiphp >& /dev/null
			fi
			;;
		"ubuntu")
			local name=`grep ^DISTRIB_CODENAME= /etc/lsb-release |sed 's/.*=//'`
			if [ "${name}" = lucid ];then
				grep -w acpiphp /etc/modules >/dev/null 2>&1 || echo acpiphp >> /etc/modules
				modprobe acpiphp >& /dev/null
			fi
			;;
		"centos")
			if [ -f /etc/centos-release ]; then
				version=`sed 's/^.*release \([0-9]\).*$/\1/' /etc/centos-release`
			elif [ -f /etc/redhat-release ]; then
				version=`sed 's/^.*release \([0-9]\).*$/\1/' /etc/redhat-release`
			else
				return
			fi
			if [  "$version" == "5"  ];then
				generate_acpipahp_file
				modprobe acpiphp >& /dev/null
			fi
			;;
		"redhat")
			local red_version=`sed -n "s/.*release.*\([0-9]\).[0-9].*/\1/p" /etc/redhat-release`
			if [  "$red_version" == "5"  ];then
				generate_acpipahp_file
				modprobe acpiphp >& /dev/null
			fi
			;;
		"opensuse")
			open_version=`grep -w VERSION_ID /etc/os-release | sed -n "s/VERSION_ID=\"\(.*\)\"/\1/p"`
			if [  "$open_version" == "12.3"  ];then
                prv=`grep -w MODULES_LOADED_ON_BOOT /etc/sysconfig/kernel | \
                sed -n "s/MODULES_LOADED_ON_BOOT=\"\(.*\)\"/\1/p"`
                echo $prv | grep -w acpiphp >/dev/null 2>&1 && return
                if [  -z "$prv"  ];then
                    sed -i "s/\(MODULES_LOADED_ON_BOOT=\"\).*\"/\1${prv}acpiphp\"/" /etc/sysconfig/kernel
                else
                    sed -i "s/\(MODULES_LOADED_ON_BOOT=\"\).*\"/\1${prv} acpiphp\"/" /etc/sysconfig/kernel
                fi
				modprobe acpiphp >& /dev/null
            fi
			;;
	esac
}

#install or update ethtool for netConfig
soft_install_for_netConfig()
{
	echo "->software insatall and update for net config......"
    local ethtool_info=$(ethtool -l eth0 2>&1)
    echo "$ethtool_info"  | grep -i "Usage:" >/dev/null 2>&1
    if [ $? -ne 0 ];then
        echo "ethtool version is ok, do nothing"
        return 0
    fi
    echo "ethtool version don't support -l and -L , upgrate it"

    case ${ostype} in
        "debian")
            apt-get -y install ethtool >/dev/null 2>&1
            ;;
        "ubuntu")
            apt-get -y install ethtool >/dev/null 2>&1
            ;;
        "centos")
            yum -y install ethtool >/dev/null  2>&1 
            ;;
        #"redhat")
            ##we don't have redhat software source
            #;;
        #"suse")
            ##we don't have suse software source
            #;;
        #"opensuse")
            #zypper in -y ethtool >/dev/null 2>&1
            #;;
    esac
}

set_rps()
{
	echo "->set rps for vm......"
	servicePath="/usr/local/qcloud/rps"
	case ${ostype} in
		"debian")
		local version=`get_debian_version`
		if [  "$version" == "6" ];then
			echo "  ->Debian 6 don't support rps......"
			return
		fi
		;;
		"ubuntu")
		local name=`grep ^DISTRIB_CODENAME= /etc/lsb-release |sed 's/.*=//'`
		if [ "${name}" = lucid ]; then #10
			echo "  ->Ubuntu 10 don't support rps......"
			return
		fi
		;;
		"centos")
		local version=`get_redhat_centos_ver`
		if [  "$version" == "5" ];then
			echo "  ->Centos 5 don't support rps......"
			return
		fi
		;;
		"redhat")
		local version=`get_redhat_centos_ver`
		if [  "$version" == "5" ];then
			echo "  ->Redhat 5 don't support rps......"
			return
		fi
		;;
		"coreos")
		servicePath="/opt/qcloud/rps"
		;;
	esac
	#for sles we can't change its software(we don't have the online repos),and rps can run ok except some ethtool judge

	[ -d $servicePath ] || mkdir -p $servicePath
	if [ ${ostype} = 'ubuntu' -o ${ostype} = 'debian' -o ${ostype} = 'FreeBSD' ]; then
		file=/etc/rc.local
	else
		file=/etc/rc.d/rc.local
	fi

	install -D $dir/set_rps.sh $servicePath/

	sed -i '/set_rps\.sh/d' $file
	cat>>$file<<EOF
$servicePath/set_rps.sh >/tmp/setRps.log 2>&1
EOF

	$servicePath/set_rps.sh >/tmp/setRps.log 2>&1
}

###shutdown irqbalance and bind virtio-input irq to last cpu
set_net_irq_bind()
{
	echo "  ->set net_irq_bind......"
	if [ ${ostype} = 'ubuntu' -o ${ostype} = 'debian' -o ${ostype} = 'FreeBSD' ]; then
		file=/etc/rc.local
	else
		file=/etc/rc.d/rc.local
	fi
	[ "$ostype" == "coreos" ] && service_dir="/opt/qcloud/irq" || service_dir="/usr/local/qcloud/irq"
	[  -d $service_dir  ] || mkdir -p $service_dir
	install -D $dir/net_smp_affinity.sh $service_dir					
	$service_dir/net_smp_affinity.sh >/tmp/net_affinity.log 2>&1
	sed -i '/net_smp_affinity\.sh/d' $file
	echo "$service_dir/net_smp_affinity.sh >/tmp/net_affinity.log 2>&1" >> $file
}

disable_irqbalance()
{
	echo "  ->disable irqbalance service......"
	if [  ${ostype} = 'ubuntu'  ];then
		service irqbalance stop 2>/dev/null
		update-rc.d -f irqbalance remove 2>/dev/null
		###some system service command doesn't work fine,kill this process
		ps -ef | grep irqbalance | grep -v grep >/dev/null && killall -9 irqbalance
		echo manual | tee /etc/init/irqbalance.override
		###ubuntu 10 need this
		sed -i 's/\(ENABLED=\)1/\10/' /etc/default/irqbalance
	elif [  ${ostype} = 'suse'  ];then
		version=`grep ^VERSION /etc/SuSE-release|awk '{print $3}'|sed 's/\..*$//'`
		if [  ${version} = '12'  ];then	
			chkconfig irqbalance off 2>/dev/null
			service irqbalance stop 2>/dev/null
		elif [  ${version} = '11' -o ${version} = '10' ];then
			service irq_balancer stop 2>/dev/null
			chkconfig irq_balancer off 2>/dev/null
		fi
	elif [ "$ostype" == "opensuse" ]; then
		local ver=`grep ^VERSION /etc/SuSE-release|awk '{print $3}'|sed 's/\..*$//'`
		if [ $ver -eq 12 ];then
			chkconfig irq_balancer off 2>/dev/null 
			systemctl disable irqbalance.service 2>/dev/null
		elif [ $ver -eq 13 ];then
			systemctl disable irqbalance.service 2>/dev/null
		fi
	elif [ "$ostype" == "centos" -o "$ostype" == "redhat" ]; then
		local ver=`get_redhat_centos_ver`
		case $ver in
			#Centos 7 don't have irqbalance  in default ,but we do it for special sistuations(user defined img)
			"7")
			systemctl list-unit-files --type=service | grep irqbalance >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				systemctl stop irqbalance 2>/dev/null 
				systemctl disable irqbalance 2>/dev/null
			fi
			;;
			"6")
			chkconfig --list | grep irqbalance >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				service irqbalance stop 2>/dev/null 
				chkconfig irqbalance off 2>/dev/null
			fi
			;;
			"5")
			chkconfig --list | grep irqbalance >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				service irqbalance stop 2>/dev/null
				chkconfig irqbalance off 2>/dev/null
			fi
			;;
		esac
	elif [ "$ostype" == "debian" ]; then
		#Debian don't have irqbalance in default,do it for special situation(user defined img)
		[ -f /etc/default/irqbalance ] && sed -i 's/\(ENABLED=\).*/\1"0"/' /etc/default/irqbalance
	fi
	#for coreOS,it have not install irqbalance by default
}

set_virtio_net_bind()
{
	echo "->set virtio net bind ......"
	disable_irqbalance
	set_net_irq_bind
}

vpcGatewaySet()
{
	[ ! -f /qcloud_init/qcloud_init.ini ] && return

	grep -iw "vpc_gateway" /qcloud_init/qcloud_init.ini | grep -i "yes" >/dev/null 2>&1
	[ $? -eq 0 ] && echo "->set vpcGateway......" || return

	[ "$ostype" == "coreos" ] && servicePath="/opt/qcloud/vpcGateway" || servicePath="/usr/local/qcloud/vpcGateway"

	[ "$ostype" == "opensuse" ] && zypper in -y iptables #opensuse don't have iptables default

	[ -d $servicePath ] || mkdir -p $servicePath 

	if [ ${ostype} = 'ubuntu' -o ${ostype} = 'debian' -o ${ostype} = 'FreeBSD' ]; then
		file=/etc/rc.local
	else
		file=/etc/rc.d/rc.local
	fi

	install -D $dir/vpcGateway.sh $servicePath/
	sed -i '/vpcGateway\.sh/d' $file

		cat>>$file<<EOF

#This is used to optimize the Gateway performance, please keep it!
$servicePath/vpcGateway.sh >/tmp/vpcGateway.log 2>&1

EOF

	$servicePath/vpcGateway.sh >/tmp/vpcGateway.log 2>&1
}

centos_remove_abrt()
{
	[ "$ostype" != "centos" ]  && return
	[ -f /etc/img_version ]  && return
	echo "->Centos remove abrt service......"
	yum remove abrt -y
}
config_kdump_tools_down()
{
	if [  "$ostype" == "debian" -o "$ostype" == "ubuntu"  ];then
		memtotal=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`
    	if [  "$memtotal" -lt "1843200"  ];then
        	[  ! -f /etc/default/kdump-tools  ] && return
        	sed -i 's/\(^USE_KDUMP=\)[1| ].*/\10/' /etc/default/kdump-tools
    	fi
	fi	
}

enable_sysrq()
{
    config_sysctl "kernel.sysrq" "/proc/sys/kernel/sysrq" "1"
}

disable_ipv6()
{
    [ -d /proc/sys/net/ipv6 ] || return
    config_sysctl "net.ipv6.conf.all.disable_ipv6" "/proc/sys/net/ipv6/conf/all/disable_ipv6" "1"
    config_sysctl "net.ipv6.conf.default.disable_ipv6" "/proc/sys/net/ipv6/conf/default/disable_ipv6" "1"
}

config_ubuntu_sudo()
{
    echo ">>>config ubuntu sudo policy......"
    sed -i '/^ubuntu.*NOPASSWD.*/d' /etc/sudoers
    echo "ubuntu  ALL=(ALL:ALL) NOPASSWD: ALL" >>/etc/sudoers
}

# recover centos7(7.0,7.1,7.3) watchdog_thresh to default value
function centos7_wathdog_thresh_fix()
{
    [ "$ostype" == "centos" ] || return # effect only on centos 
    local osver=`get_redhat_centos_ver`
    [ "$osver" == "7" ] || return #only effect on centos7

    local sysctl_key="kernel.watchdog_thresh"  
    local tmpfs_key="/proc/sys/kernel/watchdog_thresh"
    local value=10 #default value
    local file
    local tmpfile="./tmp_sysctl_file"
    [ -f /etc/sysctl.conf.first ] && file="/etc/sysctl.conf.first" || file="/etc/sysctl.conf"

    grep "$sysctl_key" "$file" &>/dev/null || return # if not set before,then return directly

    echo "--->fix centos7 watchdog_thresh:<$file>[$sysctl_key,$tmpfs_key]($value)"

    # write config file
    grep -v "$sysctl_key" $file > $tmpfile
    mv -f $tmpfile $file

    #take effect right now
    echo $value > $tmpfs_key
}

# centos7 disable chronyd service
function centos7_disable_chrnoyd()
{
    [ "$ostype" == "centos" ] || return # effect only on centos 
    local osver=`get_redhat_centos_ver`
    [ "$osver" == "7" ] || return #only effect on centos7

    systemctl stop chronyd # stop chronyd process first
    systemctl disable chronyd #disable chrnoyd service
}

# config centos7.3 overcommit_memory to 1
centos73_config_overcommit_memory()
{
    [ "$ostype" == "centos" ] || return # effect only on centos 
    ver=`grep -o "[[:digit:]]\{1,\}\.[[:digit:]]\{1,\}" /etc/centos-release`
    [ "$ver" == "7.3" ] || return # only effect on centos7.3

    config_sysctl "vm.overcommit_memory" "/proc/sys/vm/overcommit_memory" "1"
}

disable_numa_balancing()
{
	echo ">>> disable numa balancing..."
	config_sysctl "kernel.numa_balancing" "/proc/sys/kernel/numa_balancing" "0"
}

# os specific config
os_specific_config()
{
    echo "->os specific config"
    case $ostype in
        "centos")
            osver=`get_redhat_centos_ver`
            os_whole_ver=`get_redhat_centos_whole_version`
            case $osver in
                "7")
                    disable_numa_balancing
                    ;;
            esac
            ;;
    esac
}

set_centos_shmmax()
{
	if [ "$ostype" != "centos" ]; then
		return
	fi
	[ -f /etc/sysctl.conf.first ] && file="/etc/sysctl.conf.first" || file="/etc/sysctl.conf"
	[ $arch -eq 64 ] && value=68719476736 || value=1073741824
	echo $value > /proc/sys/kernel/shmmax
	grep -i "^kernel\.shmmax.*" $file &>/dev/null && sed -i "s/\(kernel\.shmmax\).*/\1=$value/" $file || echo "kernel.shmmax = $value"  >> $file
}

centos6_close_mtu_detect()
{
	if [ "$ostype" != "centos" ]; then
		return
	fi
	local ver=`get_redhat_centos_ver`
	if [ "$ver" == "6" ]; then
		echo "--->centos close mtu_detect"
		#write config file
		[ -f /etc/sysctl.conf.first ] && file="/etc/sysctl.conf.first" || file="/etc/sysctl.conf"
		tmpfile="./tmp_sysctl_file"
		grep -v "net.ipv4.ip_no_pmtu_disc" $file > $tmpfile
		echo 'net.ipv4.ip_no_pmtu_disc = 1 ' >> $tmpfile
		mv $tmpfile $file

		#take effect right now
		echo 1 > /proc/sys/net/ipv4/ip_no_pmtu_disc
	fi	
}

disable_mtu_detect_in_jr()
{
    if [ "$idc" == "szjr" -o "$idc" == "shjr" -o "$idc" == "szjrvpc" -o "$idc" == "shjrvpc" ];then
        centos6_close_mtu_detect
    fi
}

#======================================================================
#                       Set Locale to en_US.UTF-8  
#----------------------------------------------------------------------
fix_locale_by_localectl()
{
    target=$1

    if [ `localectl list-locales|grep $target` ]; then
        localectl set-locale LANG=$target
    else
        echo "system doesn't support locale" $target
    fi

    if [ "`localectl status|grep $target`" ]; then
        echo ">>>Locale success"

		#for opensuse 13.2. 
		#	some one add 4 static rule in /etc/profile and lock LANG="C"
		if [ "$LANG" != "$target" ] && [ ${ostype} == "opensuse" ];then
			sed -i '/^export LANG/d' /etc/profile
			sed -i '/^export LC_ALL/d' /etc/profile
		fi
    fi
}

fix_locale_debian()
{
    target=$1
    if [ `locale -a|grep $target` ]; then
        update-locale LANG=$target LANGUAGE=$target
    else
        echo "system doesn't support locale" $target
    fi

    if [ "`cat /etc/default/locale|grep $target`" ]; then
        echo ">>>Locale success"
    fi
}

fix_locale_SUSE_by_config_file()
{
    target=$1
    if [ -f "/etc/sysconfig/language" ]; then
        sed -i 's/^RC_LANG/\# RC_LANG/g' /etc/sysconfig/language
		sed -i 's/^ROOT_USES_LANG/\# ROOT_USES_LANG/g' /etc/sysconfig/language
        echo "RC_LANG=\"$target\"" >> /etc/sysconfig/language
		echo "ROOT_USES_LANG=\"yes\"" >> /etc/sysconfig/language
        source /etc/sysconfig/language
    else
        echo "no exist /etc/sysconfig/language"
    fi

    if [ "`locale|grep $target`" ]; then
        echo ">>>Locale success"
    fi
}

fix_locale_centos()
{
    if hash localectl 2>/dev/null; then
        fix_locale_by_localectl $1
    else
        fix_locale_redhat $1
    fi
}

fix_locale_ubuntu()
{
    if hash localectl 2>/dev/null; then
        fix_locale_by_localectl $1
    else
        echo 'no exists localectl' 
    fi
}

fix_locale_openSUSE()
{
    if hash localectl 2>/dev/null; then
        fix_locale_by_localectl $1
    else
        fix_locale_SUSE_by_config_file $1
    fi
}

fix_locale_SUSE()
{
    fix_locale_openSUSE $1
}

fix_locale_redhat()
{
    target=$1

    if [ -f "/etc/sysconfig/i18n" ]; then
        sed -i 's/^LANG/\#LANG/g' /etc/sysconfig/i18n
        echo "LANG=\"$target\"" >> /etc/sysconfig/i18n
        source /etc/sysconfig/i18n
    elif [ -f "/etc/locale.conf" ]; then
        sed -i 's/^LANG/\#LANG/g' /etc/locale.conf
        echo "LANG=\"$target\"" >> /etc/locale.conf
        source /etc/locale.conf
    fi

    if [ "`locale|grep $target`" ]; then
        echo ">>>Locale success"
    fi
}

fix_locale()
{
    local target="en_US.utf8"
    echo ">>>Config locale......"

    case ${ostype} in
    suse)
        fix_locale_SUSE $target
        ;;
    opensuse)
        fix_locale_openSUSE $target
        ;;
    centos)
        fix_locale_centos $target
        ;;
    ubuntu)
        fix_locale_ubuntu $target
        ;;
    debian)
        fix_locale_debian $target
        ;;
    redhat)
        fix_locale_redhat $target
        ;;
    esac
}


#======================================================================


#======================================================================
#                       Fix up pormpt_command bug 
#----------------------------------------------------------------------

fix_pormpt_command_by_config_file()
{
	local config_file=$1
	
	if [ -f $config_file ];then
		check_cmd=`grep "PROMPT_COMMAND=.*history" $config_file`
		if [ -z "$check_cmd" ]; then
			echo "export PROMPT_COMMAND=\"history -a; \$PROMPT_COMMAND\"" >> $config_file
		else
			sed -i 's/export PROMPT_COMMAND=\"history.*/export PROMPT_COMMAND=\"history -a; \$PROMPT_COMMAND\"/' $config_file
		fi
	else
		echo "Fix pormpt_command ERROR: $config_file not found!"
		return 0
	fi
	
	#use -m 1 because suse 13.2 has two export PROMPT_COMMAND="history -a" line
	check_cmd=`grep -m 1 -Eo "export PROMPT_COMMAND.*history.*" $config_file`

	if [ "$check_cmd" != "export PROMPT_COMMAND=\"history -a; \$PROMPT_COMMAND\"" ];then
		echo "Fix pormpt_command ERROR: Fix failed"
	else
		echo ">>>Fix pormpt_command:Fix completed."
	fi
}

#
# Debian 7,8's configure is not generated by imgcreate.
#
pre_fix_pormpt_command_debian_8()
{	
	local config_file=$1
	local deleting_file="/etc/profile.d/history_set.sh"

	#delete /etc/profile.d/history_set.sh if it exists
	if [ -f $deleting_file ];then
		echo "Fix pormpt_command: Try to clean $deleting_file"
		rm $deleting_file -f
	fi
	
	if [ -f $config_file ];then
		# cover [ "$PROMPT_COMMAND" != "history -a" ] into [ ! "$PROMPT_COMMAND" =~ "history -a"]
		sed -i 's/\[ \"\$PROMPT_COMMAND\" != \"history -a\" \]/\[\[ ! \"\$PROMPT_COMMAND\" =~ \"history -a\" \]\]/' $config_file	
		# delete '#' and ' ' in terminal title setting command. but default file comment it out?
		#sed -i "s/^#    PROMPT_COMMAND='echo -ne \"\\\033\]0/PROMPT_COMMAND='echo -ne \"\\\033\]0/"  $config_file
	fi
}

fix_pormpt_command_centos()
{
	fix_pormpt_command_by_config_file "/etc/bashrc"
}

fix_pormpt_command_ubuntu()
{
	fix_pormpt_command_by_config_file "/etc/bash.bashrc"
}

fix_pormpt_command_suse()
{
	fix_pormpt_command_by_config_file "/etc/bash.bashrc"
}

fix_pormpt_command_redhat()
{
	return 0
}

fix_pormpt_command_debian()
{
	local osver=`get_debian_version`
	local major_version=${osver%%.*}
	
	case ${major_version} in
	"7")
		pre_fix_pormpt_command_debian_8 "/etc/bash.bashrc"
		;;
	"8")
		pre_fix_pormpt_command_debian_8 "/etc/bash.bashrc"
		;;
	esac
			
	fix_pormpt_command_by_config_file "/etc/bash.bashrc"
}

fix_pormpt_command()
{
	local target="en_US.utf8"   
	echo ">>>Fix pormpt_command:Begin Fix......"

	case ${ostype} in
	suse)
		fix_pormpt_command_suse
		;;
	opensuse)
		fix_pormpt_command_suse
		;;
	centos)
		fix_pormpt_command_centos
		;;
	ubuntu)
		fix_pormpt_command_ubuntu
	  	;;
	debian)
		fix_pormpt_command_debian
	  	;;
	redhat)
		fix_pormpt_command_centos
	  	;;
	esac
}
#======================================================================
#======================================================================
#                       update initscripts for centos 6.5 
#----------------------------------------------------------------------


backupYumconfig()
{
    #backup origin yum config
    echo "->backup origin yum config"
    local yumdir="/etc/yum.repos.d"
    local tmpback=$yumdir/back_temp
    mkdir $tmpback
    mv $yumdir/*.repo $tmpback
}

recoverYumConfig()
{
    #recover origin yum config
    echo "->recover origin yum config"
    local yumdir="/etc/yum.repos.d"
    local tmpback=$yumdir/back_temp
    if [ -d $tmpback ]; then 
        rm -f $yumdir/*.repo
        mv $tmpback/*.repo $yumdir/
        rm -rf $tmpback
    fi   
    yum clean all &>/dev/null
}

centos65_update_initscripts()
{
    echo "->Install initscripts......"

    if [ "$ostype" != "centos" ]; then
        echo "->Install initscripts for centos only. return"
        return
    fi

    local osver=""
    if [ -f /etc/centos-release ]; then
        osver=$(grep -o "[[:digit:]]\{1,\}\.[[:digit:]]\{1,\}" /etc/centos-release)
    else
        echo "no file /etc/centos-release. install initscripts retutn"
        return
    fi

    if [ "$osver" != "6.5" ]; then
        echo "->Install initscripts for centos 6.5 only. return"
        return
    fi

    local osarch="i386"
    [ "$arch" == "64" ] && osarch="x86_64"

    backupYumconfig

    #$dir is a absolute path
    local yumdir="/etc/yum.repos.d"
    cat > $yumdir/local.repo <<EOF
[os]
name=imgCreateSource
baseurl=file://$dir/localrepo/6/$osarch/
enabled=1
gpgcheck=0
EOF

    yum clean all &>/dev/null
    yum makecache &>/dev/null

    echo " "
    yum -y install initscripts

    recoverYumConfig
    echo "->Install initscripts finished"
}

#======================================================================

#======================================================================
#Delete the folder /argparse-1.4.0 from the centos7.4 img and install argparse 
#tapd:http://tapd.oa.com/yundesign/bugtrace/bugs/view?bug_id=1010045391063438179 
#----------------------------------------------------------------------
del_argparse()
{
    echo "->install and delete /argparse-1.4.0  for centos 7.4 ..."

    if [ "$ostype" != "centos" ]; then
        echo "->delete argparse-1.4.0 for centos only. return"
        return
    fi

    local osver=""
    if [ -f /etc/centos-release ]; then
        osver=$(grep -o "[[:digit:]]\{1,\}\.[[:digit:]]\{1,\}" /etc/centos-release)
    else
        echo "no file /etc/centos-release.  delete retutn"
        return
    fi

    if [ "$osver" != "7.4" ]; then
        echo "->delete argparse-1.4.0 for centos 7.4 only. return"
        return
    fi

    if [ -d /argparse-1.4.0 ]; then
        pushd  /argparse-1.4.0
        python ./setup.py install
        popd
        rm -fr /argparse-1.4.0
    fi
   
    echo "->install and delete /agrparse-1.4.0 finished"
}

#======================================================================

# running from here

echo "-- basic_linux_install enter --"
echo "[Begin]:`date`"
echo "vars:$*"

if [ $# -gt 0 ];then
    idc=$1
else
    idc=gz
fi

ostype=`check_os_type`
arch=`getconf LONG_BIT`

if [ -z "${idc}" -o -z "${ostype}" ];then
    echo "ERROR: Os or idc miss"
    exit 1
fi

echo $idc > /etc/qcloudzone

if [ -f /var/lib/cloud/instance/vendor-cloud-config.txt ]; then # cloud-init
    add_data_directory
    config_logrotate  # for Custom image(centos 5 ubuntu 10,12)
    tty0_and_ttyS0_order_fix
    [ -f /etc/img_version ] || fix_centos6_ttyS0
    acpid_check
    set_acpiphp_boot_load
    soft_install_for_netConfig
    set_rps
    set_virtio_net_bind
    vpcGatewaySet
    centos_remove_abrt
    file_clear  
    generate_udev_rules
    config_kdump_tools_down
    enable_sysrq
    disable_ipv6
    centos7_wathdog_thresh_fix # recover centos7(7.0,7.1,7.3) watchdog_thresh to default value
    centos73_config_overcommit_memory # config vm.overcommit_memory=1 (only for centos 7.3)
    centos7_disable_chrnoyd
    [ ${ostype} = 'ubuntu' ] && config_ubuntu_sudo
    os_specific_config
    set_centos_shmmax
    disable_mtu_detect_in_jr
    fix_locale
    fix_pormpt_command
    $dir/gpu_init.sh
    centos65_update_initscripts #update initscripts for centos 6.5
    del_argparse
else
    add_data_directory
    ntpdate_config
    config_logrotate  # for Custom image(centos 5 ubuntu 10,12)
    config_repos "${ostype}"
    tty0_and_ttyS0_order_fix
    [ -f /etc/img_version ] || fix_centos6_ttyS0
    acpid_check
    set_acpiphp_boot_load
    soft_install_for_netConfig
    set_rps
    set_virtio_net_bind
    vpcGatewaySet
    centos_remove_abrt
    file_clear  
    generate_udev_rules
    config_kdump_tools_down
    enable_sysrq
    disable_ipv6
    centos7_wathdog_thresh_fix # recover centos7(7.0,7.1,7.3) watchdog_thresh to default value
    centos73_config_overcommit_memory # config vm.overcommit_memory=1 (only for centos 7.3)
    centos7_disable_chrnoyd
    [ ${ostype} = 'ubuntu' ] && config_ubuntu_sudo
    os_specific_config
    set_centos_shmmax
    disable_mtu_detect_in_jr
    fix_locale
    fix_pormpt_command
    $dir/gpu_init.sh
    centos65_update_initscripts #update initscripts for centos 6.5
    del_argparse
fi

echo "[End]:`date`"
echo "-- basic install success --"
#======================================================================
