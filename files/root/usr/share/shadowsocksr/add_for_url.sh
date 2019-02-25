#!/bin/bash
# Copyright (C) 2019 XiaoShan mivm.cn

. /lib/functions.sh

name=shadowsocksr

config_load $name

urlsafe_b64decode() { # 安全解码 base64
    local d="====" data=$(echo $1 | sed 's/_/\//g; s/-/+/g')
    local mod4=$((${#data}%4))
    [ $mod4 -gt 0 ] && data=${data}${d:mod4}
    echo $data | base64 -d
}

Server_Update() { # 更新服务器数据
    local uci_set="uci -q set $name.$1."
    ${uci_set}alias="$2 : $ssr_port"
    ${uci_set}server="$3"
    ${uci_set}server_port="$ssr_port"
    ${uci_set}password="$ssr_passwd"
    uci -q get $name.@servers[$1].timeout >/dev/null || ${uci_set}timeout="60"
    ${uci_set}encrypt_method="$ssr_method"
    ${uci_set}protocol="$ssr_protocol"
    ${uci_set}protocol_param="$ssr_protoparam"
    ${uci_set}obfs="$ssr_obfs"
    ${uci_set}obfs_param="$ssr_obfsparam"
}

check_server() { # 检查服务器
    is_exist() { # 当前服务器是否存在
        [ $server_exist -eq 1 ] && return 0
        local ip_t=$(uci -q get $name.$1.server)
        local port_t=$(uci -q get $name.$1.server_port)
        [ "$ip_t" == "$ip" -a "$port_t" == $ssr_port ] && {
            server_exist=1
            server_uci_name=$1
        }
    }
    local ips
    local ip=$2
    ckipver $ip
    local ipver=$?
    local flag
    [ $1 -eq 4 ] && flag=a
    [ $1 -eq 6 ] && flag=aaaa
    if [ $ipver -ne $1 ]; then # 如果地址不是IP 则解析IP
        ips=($(dig $2 $flag +short))
        for ((i=0;i<${#ips[@]};i++))
        do
            ip=${ips[i]}
            ckipver $ip
            ipver=$?
            [ $ipver -eq $1 ] && continue
            ip=""
        done
    fi
    [ $ipver -ne $1 ] && return 1
    local server_exist=0
    local server_uci_name
    config_foreach is_exist servers
    if [ $server_exist -eq 0 ]; then # 判断当前服务器信息是否存在
        server_uci_name=$(uci add $name servers)
        subscribe_n=$(($subscribe_n + 1))
    fi
    Server_Update $server_uci_name "${ssr_remarks}_v$1" $ip
    subscribe_x=${subscribe_x}"$ip:$ssr_port"" "
    # echo "服务器地址: $ip"
    # echo "服务器端口 $ssr_port"
    # echo "密码: $ssr_passwd"
    # echo "加密: $ssr_method"
    # echo "协议: $ssr_protocol"
    # echo "协议参数: $ssr_protoparam"
    # echo "混淆: $ssr_obfs"
    # echo "混淆参数: $ssr_obfsparam"
    # echo "备注: $ssr_remarks"
}

[ $# -ne 1 ] && exit 1

temp_info=$(urlsafe_b64decode ${1//ssr:\/\//}) # 解码 SSR 链接
info=${temp_info///?*/}
temp_info_array=(${info//:/ })
ssr_host=${temp_info_array[0]}
ssr_port=${temp_info_array[1]}
ssr_protocol=${temp_info_array[2]}
ssr_method=${temp_info_array[3]}
ssr_obfs=${temp_info_array[4]}
ssr_passwd=$(urlsafe_b64decode ${temp_info_array[5]})
info=${temp_info:$((${#info} + 2))}
info=(${info//&/ })
ssr_protoparam=""
ssr_obfsparam=""
ssr_remarks="$temp_x"
for ((i=0;i<${#info[@]};i++)) # 循环扩展信息
do
    temp_info=($(echo ${info[i]} | sed 's/=/ /g'))
    case "${temp_info[0]}" in
        protoparam)
            ssr_protoparam=$(urlsafe_b64decode ${temp_info[1]})
        ;;
        obfsparam)
            ssr_obfsparam=$(urlsafe_b64decode ${temp_info[1]})
        ;;
        remarks)
            ssr_remarks=$(urlsafe_b64decode ${temp_info[1]})
        ;;
    esac
done
check_server 4 $ssr_host
check_server 6 $ssr_host
uci commit $name