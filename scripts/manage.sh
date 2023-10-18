#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'


arch=$(uname -m)
version="v1.0.0"
latestVersion=''
downloadUrl='https://github.com/ppoonk/XrayR-for-AirGo/releases/download/'
apiUrl='https://api.github.com/repos/ppoonk/XrayR-for-AirGo/releases/latest'
manageUrl='https://raw.githubusercontent.com/ppoonk/XrayR-for-AirGo/main/scripts/manage.sh'
bbrUrl='https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

get_region() {
    country=$( curl -4 "https://ipinfo.io/country" 2> /dev/null )
    if [ "$country" == "CN" ]; then
      downloadUrl="https://gh-proxy.com/${downloadUrl}"
      manageUrl="https://gh-proxy.com/${manageUrl}"
      bbrUrl="https://gh-proxy.com/${bbrUrl}"
    fi
}
get_arch(){
  if [[ $arch == "x86_64" || $arch == "x64" || $arch == "64" ]]; then
      arch="64"
  elif [[ $arch == "aarch64" || $arch == "arm64" || $arch == "armv8" || $arch == "armv8l" ]]; then
      arch="arm64-v8a"
  elif [[ $arch == "arm"  || $arch == "armv7" || $arch == "armv7l" || $arch == "armv6" ]];then
      arch="arm32-v7a"
  else
      echo -e ${red}"不支持的arch，请自行编译\n"${plain}
      exit 1
  fi
}
get_latest_version() {
          latestVersion=$(curl -Ls ${apiUrl} | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
          if [[ ! -n "$latestVersion" ]]; then
              echo -e "${red}获取最新版本失败，请稍后重试${plain}"
              exit 1
          fi
}


os_version=""

# os version
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

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启XrayR" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按回车返回主菜单: ${plain}" && read temp
    show_menu
}

download(){
  echo -e "开始下载核心"
  rm -rf /usr/local/XrayR
  mkdir /usr/local/XrayR

  wget -N --no-check-certificate -O /usr/bin/XrayR ${manageUrl}
  chmod 777 /usr/bin/XrayR

  wget -N --no-check-certificate -O /usr/local/XrayR/XrayR.zip ${downloadUrl}${latestVersion}/XrayR-linux-${arch}.zip
  if [[ $? -ne 0 ]]; then
      echo -e "${red}下载失败，请重试${plain}"
      exit 1
  fi
  echo -e "开始解压..."
  cd /usr/local/XrayR/
  unzip XrayR.zip
  chmod 777 -R /usr/local/XrayR

}
add_service(){
  rm -rf /etc/systemd/system/$1.service
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

install() {
  download
  add_service "XrayR"
  systemctl daemon-reload
  systemctl stop XrayR
  systemctl enable XrayR
      echo -e ""
      echo "XrayR 管理脚本使用方法 (兼容使用xrayr执行，大小写不敏感): "
      echo "------------------------------------------"
      echo "XrayR                    - 显示管理菜单 (功能更多)"
      echo "XrayR start              - 启动 XrayR"
      echo "XrayR stop               - 停止 XrayR"
      echo "XrayR restart            - 重启 XrayR"
      echo "XrayR status             - 查看 XrayR 状态"
      echo "XrayR enable             - 设置 XrayR 开机自启"
      echo "XrayR disable            - 取消 XrayR 开机自启"
      echo "XrayR log                - 查看 XrayR 日志"
      echo "XrayR update             - 更新 XrayR"
      echo "XrayR update x.x.x       - 更新 XrayR 指定版本"
      echo "XrayR config             - 显示配置文件内容"
      echo "XrayR install            - 安装 XrayR"
      echo "XrayR uninstall          - 卸载 XrayR"
      echo "XrayR version            - 查看 XrayR 版本"
      echo "------------------------------------------"

}

update() {
    wget -N --no-check-certificate -O /usr/bin/XrayR ${manageUrl}
    chmod 777 /usr/bin/XrayR
    if [[ $# == 0 ]]; then
        echo && echo -n -e "输入指定版本(默认最新版): " && read version
    else
        latestVersion=$2
    fi
    rm -rf /usr/local/XrayR/temp
    mkdir /usr/local/XrayR/temp
    cd /usr/local/XrayR/temp
    wget -N --no-check-certificate -O XrayR.zip ${downloadUrl}${latestVersion}/XrayR-linux-${arch}.zip
    unzip XrayR.zip
    cd ..
    date=$(date +%Y_%m_%d_%H_%M)
    mv XrayR XrayR_old_${date}
    mv ./temp/XrayR XrayR

    restart

    echo -e "${green}更新完成，原XrayR备份为：XrayR_old_${date}，已自动重启 XrayR，请使用 XrayR log 查看运行日志${plain}"
    before_show_menu
}

config() {
    echo "XrayR在修改配置后会自动尝试重启"
    vi /usr/local/XrayR/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "XrayR状态: ${green}已运行${plain}"
            ;;
        1)
            echo -e "检测到您未启动XrayR或XrayR自动重启失败，是否查看日志？[Y/n]" && echo
            read -e -p "(默认: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "XrayR状态: ${red}未安装${plain}"
    esac
}

uninstall() {
    confirm "确定要卸载 XrayR 吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop XrayR
    systemctl disable XrayR
    rm /etc/systemd/system/XrayR.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /usr/local/XrayR/ -rf

    echo ""
    echo -e "卸载成功，如果你想删除此脚本，则退出脚本后运行 ${green}rm /usr/bin/XrayR -f${plain} 进行删除"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}XrayR已运行，无需再次启动，如需重启请选择重启${plain}"
    else
        systemctl start XrayR
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR 启动成功，请使用 XrayR log 查看运行日志${plain}"
        else
            echo -e "${red}XrayR可能启动失败，请稍后使用 XrayR log 查看日志信息${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop XrayR
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}XrayR 停止成功${plain}"
    else
        echo -e "${red}XrayR停止失败，可能是因为停止时间超过了两秒，请稍后查看日志信息${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart XrayR
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR 重启成功，请使用 XrayR log 查看运行日志${plain}"
    else
        echo -e "${red}XrayR可能启动失败，请稍后使用 XrayR log 查看日志信息${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status XrayR --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR 设置开机自启成功${plain}"
    else
        echo -e "${red}XrayR 设置开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR 取消开机自启成功${plain}"
    else
        echo -e "${red}XrayR 取消开机自启失败${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u XrayR.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s "${bbr}")
    #if [[ $? == 0 ]]; then
    #    echo ""
    #    echo -e "${green}安装 bbr 成功，请重启服务器${plain}"
    #else
    #    echo ""
    #    echo -e "${red}下载 bbr 安装脚本失败，请检查本机能否连接 Github${plain}"
    #fi

    #before_show_menu
}

update_shell() {
    wget -O /usr/bin/XrayR -N --no-check-certificate ${manageUrl}
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}下载脚本失败，请检查本机能否连接 Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/XrayR
        echo -e "${green}升级脚本成功，请重新运行脚本${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled XrayR)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}XrayR已安装，请不要重复安装${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}请先安装XrayR${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "XrayR状态: ${green}已运行${plain}"
            show_enable_status
            ;;
        1)
            echo -e "XrayR状态: ${yellow}未运行${plain}"
            show_enable_status
            ;;
        2)
            echo -e "XrayR状态: ${red}未安装${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自启: ${green}是${plain}"
    else
        echo -e "是否开机自启: ${red}否${plain}"
    fi
}

show_XrayR_version() {
    echo -n "XrayR 版本："
    /usr/local/XrayR/XrayR version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
    echo "XrayR 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "XrayR              - 显示管理菜单 (功能更多)"
    echo "XrayR start        - 启动 XrayR"
    echo "XrayR stop         - 停止 XrayR"
    echo "XrayR restart      - 重启 XrayR"
    echo "XrayR status       - 查看 XrayR 状态"
    echo "XrayR enable       - 设置 XrayR 开机自启"
    echo "XrayR disable      - 取消 XrayR 开机自启"
    echo "XrayR log          - 查看 XrayR 日志"
    echo "XrayR update       - 更新 XrayR"
    echo "XrayR update x.x.x - 更新 XrayR 指定版本"
    echo "XrayR install      - 安装 XrayR"
    echo "XrayR uninstall    - 卸载 XrayR"
    echo "XrayR version      - 查看 XrayR 版本"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}XrayR 后端管理脚本，${plain}${red}不适用于docker${plain}
--- 官方：https://github.com/XrayR-project/XrayR ---
--- 适配AirGo：https://github.com/ppoonk/XrayR-for-AirGo ---
  ${green}0.${plain} 修改配置
————————————————
  ${green}1.${plain} 安装 XrayR
  ${green}2.${plain} 更新 XrayR
  ${green}3.${plain} 卸载 XrayR
————————————————
  ${green}4.${plain} 启动 XrayR
  ${green}5.${plain} 停止 XrayR
  ${green}6.${plain} 重启 XrayR
  ${green}7.${plain} 查看 XrayR 状态
  ${green}8.${plain} 查看 XrayR 日志
————————————————
  ${green}9.${plain} 设置 XrayR 开机自启
 ${green}10.${plain} 取消 XrayR 开机自启
————————————————
 ${green}11.${plain} 一键安装 bbr (最新内核)
 ${green}12.${plain} 查看 XrayR 版本
 ${green}13.${plain} 升级维护脚本
 "
 #后续更新可加入上方字符串中
    show_status
    echo && read -p "请输入选择 [0-13]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_XrayR_version
        ;;
        13) update_shell
        ;;
        *) echo -e "${red}请输入正确的数字 [0-12]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_XrayR_version 0
        ;;
        "update_shell") update_shell
        ;;
        *) show_usage
    esac
else
    get_region
    get_arch
    get_latest_version
    show_menu
fi