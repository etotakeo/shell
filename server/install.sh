#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear

# get pwd
sed -i "s@^oneinstack_dir.*@oneinstack_dir=`pwd`@" ./options.conf

#mkdir src
if [ ! -d `pwd`/include ]; then
  mkdir include
fi
if [ ! -d `pwd`/src ]; then
  mkdir src
fi
. ./options.conf	#程序路径
. ./include/color.sh	#格式化脚本颜色?
. ./include/check_os.sh	#检测系统
. ./include/download.sh	#下载后调用,检测文件是否下载成功
. ./include/get_char.sh	#规范指令输出

# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}错误：您必须是root用户才能运行此脚本${CEND}"; exit 1; }

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

ssh(){
# Use default SSH port 22. If you use another SSH port on your server
if [ -e "/etc/ssh/sshd_config" ]; then
  [ -z "`grep ^Port /etc/ssh/sshd_config`" ] && ssh_port=22 || ssh_port=`grep ^Port /etc/ssh/sshd_config | awk '{print $2}'`
  while :; do echo
    read -p "请输入新的SSH端口（当前端口: $ssh_port): " SSH_PORT
    [ -z "$SSH_PORT" ] && SSH_PORT=$ssh_port
    if [ $SSH_PORT -eq 22 >/dev/null 2>&1 -o $SSH_PORT -gt 1024 >/dev/null 2>&1 -a $SSH_PORT -lt 65535 >/dev/null 2>&1 ]; then
      break
    else
      echo "${CWARNING}输入错误！ 输入范围: 22,1025~65534${CEND}"
    fi
  done

  if [ -z "`grep ^Port /etc/ssh/sshd_config`" -a "$SSH_PORT" != '22' ]; then
    sed -i "s@^#Port.*@&\nPort $SSH_PORT@" /etc/ssh/sshd_config
  elif [ -n "`grep ^Port /etc/ssh/sshd_config`" ]; then
    sed -i "s@^Port.*@Port $SSH_PORT@" /etc/ssh/sshd_config
  fi
fi

# check iptables
iptables_yn=n
chkconfig iptables off && service iptables stop
systemctl disable firewalld && systemctl stop firewalld

# init
startTime=`date +%s`
pushd ${oneinstack_dir}
. ./include/memory.sh
case "${OS}" in
  "CentOS")
    . include/init_CentOS.sh 2>&1 | tee -a ${oneinstack_dir}/src/install.log
    [ -n "$(gcc --version | head -n1 | grep '4\.1\.')" ] && export CC="gcc44" CXX="g++44"
    ;;
  "Debian")
    . include/init_Debian.sh 2>&1 | tee -a ${oneinstack_dir}/src/install.log
    ;;
  "Ubuntu")
    . include/init_Ubuntu.sh 2>&1 | tee -a ${oneinstack_dir}/src/install.log
    ;;
esac
popd
}
#检测锐速系统
Check_serverSpeeder() {
# ACCEPT
if [ "${OS}" == 'CentOS' ]; then
  #echo "${CWARNING}${OS}${CentOS_RHEL_version}${CEND}"
    if [ "${CentOS_RHEL_version}" == '5' ]; then
      echo "${CWARNING}不支持 ${OS} ${CentOS_RHEL_version}${CEND}"
      exit
    else
      echo "${CWARNING}${OS} ${CentOS_RHEL_version}${CEND}"
      echo "${CBLUE}当前共有内核为↓${CEND}"
      rpm -qa | grep kernel
      echo "${CBLUE}---------------${CEND}"
      echo "${CBLUE}当前内核为↓${CEND}"
      uname -r
      echo "${CBLUE}---------------${CEND}"
      echo "${CBLUE} ${CEND}"
      echo "${CBLUE}CentOS 6 内核需要大于 2.6.32-642.el6${CEND}"
      echo "${CBLUE}CentOS 7 内核需要大于 3.10.0-229.1.2.el7${CEND}"
      echo "${CBLUE}否则请中断本脚本并运行 yum update -y 来升级内核${CEND}"
      while :; do echo
  read -p "你已经确认内核版本,并执意更换内核吗[y/n]: " serverSpeeder
  if [[ ! $serverSpeeder =~ ^[y,n]$ ]]; then
    echo "${CWARNING}输入错误！ 请只输入 'y' or 'n'${CEND}"
  else
    break
  fi
done
kernel_serverSpeeder
    fi
  elif [[ ${OS} =~ ^Ubuntu$|^Debian$ ]]; then
    echo "${CWARNING}未做${OS} 的脚本部分.请自行编写${CEND}"
fi
}
#锐速更换核心
kernel_serverSpeeder() {
if [[ $serverSpeeder == 'y' ]]; then
  echo "${CBLUE}----当前内核为↓---${CEND}"
  rpm -qa | grep kernel
  echo "${CBLUE}-------------------------${CEND}"
  if [ "${CentOS_RHEL_version}" == '6' ]; then
  #核心6
  echo "${CBLUE}更换${CWARNING}${OS} ${CentOS_RHEL_version} 内核为 2.6.32-642.el6${CEND}"
  rpm -ivh http://ftp.scientificlinux.org/linux/scientific/6.6/x86_64/updates/security/kernel-firmware-2.6.32-642.el6.noarch.rpm --force
  rpm -ivh http://ftp.scientificlinux.org/linux/scientific/6.6/x86_64/updates/security/kernel-2.6.32-642.el6.x86_64.rpm --force
  echo "${CBLUE}安装完成后需要手动重启${CEND}"
  else
  #核心7
  echo "${CBLUE}更换${CWARNING}${OS} ${CentOS_RHEL_version} 内核为 3.10.0-229.1.2.el7${CEND}"
  rpm -ivh http://soft.91yun.org/ISO/Linux/CentOS/kernel/kernel-3.10.0-229.1.2.el7.x86_64.rpm --force
  echo "${CBLUE}安装完成后需要手动重启${CEND}"
  fi
fi
}
Unix_int(){
echo -e "${CYELLOW}初始化${OS}常用软件开始，请等待${CEND}"
if [ "${OS}" == 'CentOS' ]; then
  yum install lrzsz tree net-tools nmap vim bash-completion lsof dos2unix nc telnet ntp wget rng-tools psmisc screen git -y
  #yum install epel* -y && yum install python-pip -y #修复pip无法安装的错误
  else
  apt-get install lrzsz tree net-tools nmap vim bash-completion lsof dos2unix telnet ntp wget rng-tools psmisc screen git -y
  apt-get build-dep python -y
fi
	echo -e "${CYELLOW}初始化${OS}常用软件完毕${CEND}"
}
test_a(){
  wget -N --no-check-certificate https://raw.githubusercontent.com/FunctionClub/ZBench/master/ZBench-CN.sh && bash ZBench-CN.sh
}
test_b(){
	curl -k -Lso- https://raw.githubusercontent.com/oooldking/script/master/superbench.sh | bash
}
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
	clear
    [ ! -z ${IP} ] && echo 网卡 IP：${IP} || echo
}

#菜单
Menu(){
get_ip
  while :; do
    printf "

	你需要做什么
\t${CMSG}1${CEND}. ${CBLUE}安装常用组件${CEND} ${CRED}/${CEND} ${CMSG}2${CEND} ${CBLUE}配置新的ssh端口${CEND}
\t${CMSG}3${CEND}. ${CBLUE}安装魔改后端${CEND} ${CRED}/${CEND} ${CMSG}4${CEND} ${CBLUE}魔改后端更新ID${CEND}
\t${CMSG}5${CEND}. ${CBLUE}查看机器信息${CEND} ${CRED}/${CEND} ${CMSG}6${CEND} ${CBLUE}查看机器信息B${CEND}
\t${CMSG}7${CEND}. ${CBLUE}查看守护状态${CEND} ${CRED}/${CEND} ${CMSG}8${CEND} ${CBLUE}重启守护${CEND}
\t${CMSG}a${CEND}. ${CBLUE}锐速/BBR安装${CEND} ${CRED}/${CEND} ${CMSG}b${CEND} ${CBLUE}BBR状态${CEND}
\t${CMSG}c${CEND}. ${CBLUE}锐速状态${CEND} ${CRED}/${CEND} ${CMSG}d${CEND} ${CBLUE}锐速重启${CEND}

\t${CMSG}e${CEND}. ${CBLUE}更改系统语言为中文${CEND}

\t${CMSG}q${CEND}. ${exit}退出${CEND}
"
    echo
    read -p "请输入正确的选项: " Number
    if [[ ! $Number =~ ^[1-9,a,b,c,d,e,q]$ ]]; then
      echo "${CWARNING}输入错误！ 请只输入 1,2,3,4,5,6 and a,b,c,d,e and q${CEND}"
    else
      case "$Number" in
      1)
        disable_selinux
        Unix_int
        ;;
      2)
        ssh
        ;;
      3)
        disable_selinux
        . ./manyuser.sh install
        ;;
      4)
        . ./manyuser.sh upconfig
        ;;
      5)
        test_a
        ;;
      6)
        test_b
        ;;
      7)
        echo -e "${OS}---守护状态--"
        if [ "${OS}" == 'CentOS' ]; then
          service supervisord status
        else
          supervisorctl status ssr
        fi
        echo -e "${OS}---python状态--"
        ps aux | grep  python | grep -v grep
        ;;
      8)
        if [ "${OS}" == 'CentOS' ]; then
          service supervisord restart
          echo "重启. service supervisord restart"
          echo "关闭. service supervisord stop"
        else
          supervisorctl restart ssr
          echo "重启. supervisorctl restart ssr"
          echo "关闭. supervisorctl stop ssr"
        fi
        echo -e "${OS}---守护操作完毕--"
        ;;
      9)
        rm -rf /root/appex.sh;wget --no-check-certificate -O appex.sh https://raw.githubusercontent.com/0oVicero0/serverSpeeser_Install/master/appex.sh && chmod +x appex.sh && bash appex.sh install        
        ;;
      a)
      	echo -e "Info: 是否使用推荐的换源脚本？[Y/n]"
      	read -p "(默认: y):" yn
	      [[ -z "${yn}" ]] && yn="y"
      	if [[ ${yn} == [Yy] ]]; then
        wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
        else
        read -p "警告：本模式未经验证很容易炸内核!!! 按任意键继续.......按Ctrl + C取消" var
        Check_serverSpeeder
	      fi
        ;;
      b)
        sysctl net.core.default_qdisc
        sysctl net.ipv4.tcp_congestion_control
        lsmod | grep bbr
        ;;
      c)
        /appex/bin/serverSpeeder.sh status
        ;;
      d)
        /appex/bin/serverSpeeder.sh restart
        ;;
      e)
        read -p "按任意键继续安装...按Ctrl + C取消" var
        wget -N --no-check-certificate https://raw.githubusercontent.com/FunctionClub/LocaleCN/master/LocaleCN.sh && bash LocaleCN.sh
        ;;
      q)
        exit
        ;;
      esac
    fi
  done
}

if [ $# == 0 ]; then
  Menu
elif [ $# == 1 ]; then
  case $1 in
  *)
    echo "错误的执行命令"
    ;;
  esac
fi
