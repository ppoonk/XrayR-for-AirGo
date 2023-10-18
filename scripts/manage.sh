#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && ${red}"非root权限\n"${plain} && exit 1

arch=$(uname -m)
os_version=""

appName='XrayR'
country=''
downloadPrefix='https://github.com/ppoonk/XrayR-for-AirGo/releases/download/'
manageScript="https://raw.githubusercontent.com/ppoonk/XrayR-for-AirGo/main/scripts/manage.sh"
githubApi="https://api.github.com/repos/ppoonk/XrayR-for-AirGo/releases/latest"


os_version(){
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi
}
get_arch(){
  if [[ $arch == "x86_64" || $arch == "x64" || $arch == "64" ]]; then
      arch="64"
  elif [[ $arch == "aarch64" || $arch == "arm64" || $arch == "armv8" || $arch == "armv8l" ]]; then
      arch="arm64-v8a"
  elif [[ $arch == "arm"  || $arch == "armv7" || $arch == "armv7l" || $arch == "armv6" ]];then
      arch="arm64-v7a"
  else
      echo -e ${red}"不支持的arch，请自行编译\n"${plain}
      exit 1
  fi
}
get_region() {
    country=$( curl -4 "https://ipinfo.io/country" 2> /dev/null )
    if [ "$country" == "CN" ]; then
      acmeGit="https://gitee.com/neilpang/acme.sh.git"
      downloadPrefix="https://ghproxy.com/${downloadPrefix}"
      installScript="https://ghproxy.com/${installScript}"
    fi
}
open_ports(){
	systemctl stop firewalld.service >/dev/null 2>&1
	systemctl disable firewalld.service >/dev/null 2>&1
	setenforce 0 >/dev/null 2>&1
	ufw disable >/dev/null 2>&1
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -t nat -F
	iptables -t mangle -F
	iptables -F
	iptables -X
}

set_dependences() {
    if [[ $(command -v yum) ]]; then
      if [[ ! $(command -v wget) ]] || [[ ! $(command -v curl) ]] || [[ ! $(command -v git) ]] || [[ ! $(command -v socat) ]] || [[ ! $(command -v unzip) ]] || [[ ! $(command -v gawk) ]] || [[ ! $(command -v lsof) ]]; then
          echo -e ${green}"安装依赖\n"${plain}
          yum update -y
          yum install wget curl git socat unzip gawk lsof -y
      fi
    elif [[ $(command -v apt) ]]; then
      if [[ ! $(command -v wget) ]] || [[ ! $(command -v curl) ]] || [[ ! $(command -v git) ]] || [[ ! $(command -v socat) ]] || [[ ! $(command -v unzip) ]] || [[ ! $(command -v gawk) ]] || [[ ! $(command -v lsof) ]]; then
          echo -e ${green}"安装依赖\n"${plain}
          apt update -y
          apt install wget curl git socat unzip gawk lsof -y
      fi
       echo -e "依赖已安装\n"
    fi
}
get_latest_version() {
          latestVersion=$(curl -Ls $githubApi | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
          if [[ ! -n "$latestVersion" ]]; then
              echo -e "${red}获取最新版本失败，请稍后重试${plain}"
              exit 1
          fi
}
initialize(){
  get_arch
  os_version
  set_dependences
  get_region
  get_latest_version
}

confirm_msg() {
    if [[ $# -gt 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ "${temp}x" == ""x ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ "${temp}"x == "y"x || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

installation_status(){
      if [[ ! -f /etc/systemd/system/$1.service ]] || [[ ! -f /usr/local/$1/$1 ]]; then
        return 1
      else
        return 0
      fi
}
run_status() {
      temp=$(systemctl is-active $1)
      if [[ x"${temp}" == x"active" ]]; then
          return 0
      else
          count=$(ps -ef | grep "$1" | grep -v "grep" | wc -l)
          if [[ count -ne 0 ]]; then
              return 0
          else
              return 1
          fi
      fi
}


download(){
  echo -e "开始下载核心，版本：${latestVersion}"
  rm -rf /usr/local/$1
  mkdir /usr/local/$1

  wget -N --no-check-certificate -O /usr/bin/$1 ${manageScript}
  chmod 777 /usr/bin/$1

  wget -N --no-check-certificate -O /usr/local/$1/$1.zip ${downloadPrefix}${latestVersion}/$1-linux-${arch}.zip
  if [[ $? -ne 0 ]]; then
      echo -e "${red}下载失败，请重试${plain}"
      exit 1
  fi
  echo -e "开始解压..."
  cd /usr/local/$1/
  unzip $1.zip
  chmod 777 -R /usr/local/$1/*

}
add_service(){
  cat >/etc/systemd/system/$1.service <<-EOF
  [Unit]
  Description=$1 Service
  After=network.target
  Wants=network.target
  StartLimitIntervalSec=0

  [Service]
  Restart=always
  RestartSec=1
  Type=simple
  WorkingDirectory=/usr/local/$1/
  ExecStart=/usr/local/$1/$1

  [Install]
  WantedBy=multi-user.target
EOF

}
install(){
  installation_status $1
  if [[ $? -eq 0 ]]; then
      echo -e "${red}已安装${plain}"
      echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
      main
  fi

  run_status $1
  if [[ $? -eq 0 ]]; then
   echo -e "${red}正在运行${plain}"
   echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
   main
  fi

  download $1
  add_service $1
  systemctl daemon-reload
  systemctl enable $1

  echo -e "${green}安装完成，版本：${latestVersion}${plain}"

  echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
  main
}
uninstall(){
  confirm_msg "确定要卸载吗?" "n"
      if [[ $? != 0 ]]; then
          return 0
      fi
  echo -e "开始卸载"
      systemctl stop $1
      systemctl disable $1
      systemctl daemon-reload
      systemctl reset-failed
      rm -rf /etc/systemd/system/$1.service /usr/local/$1

  echo -e "${green}卸载完成${plain}"
  echo
  echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
  main
}

start(){

  installation_status $1
  if [[ $? -eq 1 ]]; then
      echo -e "${red}未安装${plain}"
      echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
      main
  fi

  run_status $1
  if [[ $? -eq 0 ]]; then
   echo -e "${red}正在运行${plain}"
   echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
   main
  fi

  systemctl start $1
  systemctl is-active $1

  echo -e "${green}操作完成${plain}"
#  echo -e "${green}公网访问：${ipv4}:${httpPort}${plain}"
#  echo -e "${green}内网访问：${ipv4_local}:${httpPort}${plain}"
#  echo -e "${yellow}个别vps上述地址无法访问请更换端口${plain}"
#  echo
  echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
  main
}
stop(){
    installation_status $1
    if [[ $? -eq 1 ]]; then
        echo -e "${red}未安装${plain}"
        echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
        main
    fi

    run_status $1
    if [[ $? -eq 1 ]]; then
     echo -e "${red}未运行${plain}"
     echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
     main
    fi

  systemctl stop $1
  systemctl is-active $1
  echo -e "${green}操作完成${plain}"
  echo
  echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
  main
}



acme(){
  git clone ${acmeGit}

  cd acme.sh

  email=''
  domain=''

  echo -e "${yellow}设置Acme邮箱:${plain}"
  read -p "输入您的邮箱:" email
  echo -e "您的邮箱:${email}"

  echo -e "${yellow}设置域名:${plain}"
  read -p "输入您的域名:" domain
  echo -e "您的域名:${domain}"
  domainPrefix=$(echo ${domain%%.*})

  echo -e "${yellow}配置邮箱账户...${plain}"
  ./acme.sh --install -m ${email}
  echo -e "${yellow}正在发起 DNS 申请...${plain}"
  ./acme.sh --issue --dns -d ${domain} --yes-I-know-dns-manual-mode-enough-go-ahead-please

  echo -e "${yellow}请仔细查看命令行显示文本中，有无以下字段：${plain}"
  echo -e "[Tue Sep 12 12:30:59 UTC 2023] TXT value: '**************************************-****"

  echo -e "${yellow}如果存在该字段，请去你的域名 DNS 管理商，完成下面2个重要操作！！！${plain}"
  echo -e "${yellow}1、${plain}添加一个txt记录"
  echo -e "${yellow}2、${plain}将该记录的[名称]设置为：_acme-challenge.${domainPrefix}，完整域名为 _acme-challenge.${domain}"
  echo

  confirm_msg "是否已经添加这条 txt 记录？是否将该记录的[名称]设置为：_acme-challenge.${domainPrefix}？ "
   if [[ $? -ne 0 ]]; then
     echo -e "${red}未添加txt 记录,脚本退出${plain}"
     exit 1
   fi

  echo -e "${green}添加 txt 记录成功，进行下一步${plain}"
  echo -e "${green}开始申请证书...${plain}"

  ./acme.sh --renew -d ${domain} --yes-I-know-dns-manual-mode-enough-go-ahead-please
    if [ $? -ne 0 ]; then
        echo -e "${red}申请失败,脚本退出${plain}"
        exit 1
    fi
  echo -e "${green}申请成功,证书文件在/root/.acme.sh/${domain}文件夹下${plain}"
  echo -e "${green}正在将证书复制到/usr/local/$1/${plain}"

  cp /root/.acme.sh/${domain}*/${domain}.cer /usr/local/$1/air.cer
  cp /root/.acme.sh/${domain}*/${domain}.key /usr/local/$1/air.key

}
main(){
  clear
  installationStatus='未安装'
  runStatus='未运行'
  installation_status $appName
  if [[ $? -eq 0 ]]; then
    installationStatus='已安装'
  fi
  run_status $appName
    if [[ $? -eq 0 ]]; then
      runStatus='已运行'
    fi

  echo -e "
  ${green}${appName} 管理脚本${plain}

  状态： ${green}${installationStatus}${plain}    ${green}${runStatus}${plain}
  ${yellow}-------------------------${plain}
  ${green}1.${plain} 安装
  ${green}2.${plain} 卸载
  -${yellow}------------------------${plain}
  ${green}3.${plain} 启动
  ${green}4.${plain} 停止
  ${yellow}-------------------------${plain}
  ${green}0.${plain} 退出
 "

  echo && read -p "请输入序号: " tem
  case "${tem}" in
  1) install $appName;;
  2) uninstall $appName;;
  3) start $appName;;
  4) stop $appName;;
  *) exit 0;;

  esac

}
initialize
main