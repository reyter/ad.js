#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 6+/Debian 6+/Ubuntu 14.04+
#	Description: Install the ShadowsocksR server
#	Version: 2.0.37
#	Author: Toyo
#	Blog: https://doub.io/ss-jc42/
#=================================================

sh_ver="2.0.37"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
ssr_folder="/usr/local/shadowsocksr"
ssr_ss_file="${ssr_folder}/shadowsocks"
config_file="${ssr_folder}/config.json"
config_folder="/etc/shadowsocksr"
config_user_file="${config_folder}/user-config.json"
ssr_log_file="${ssr_ss_file}/ssserver.log"
Libsodiumr_file="/usr/local/lib/libsodium.so"
Libsodiumr_ver_backup="1.0.13"
Server_Speeder_file="/serverspeeder/bin/serverSpeeder.sh"
LotServer_file="/appex/bin/serverSpeeder.sh"
BBR_file="${file}/bbr.sh"
jq_file="${ssr_folder}/jq"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[Info]${Font_color_suffix}"
Error="${Red_font_prefix}[Error]${Font_color_suffix}"
Tip="${Green_font_prefix}[Warning]${Font_color_suffix}"
Separator_1="——————————————————————————————"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} The current account is not ROOT (or ROOT permissions), unable to continue operation, please use${Green_background_prefix} sudo su ${Font_color_suffix}To get temporary ROOT permissions (the password to be prompted to enter the current account after execution)。" && exit 1
}
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}
check_pid(){
	PID=`ps -ef |grep -v grep | grep server.py |awk '{print $2}'`
}
SSR_installation_status(){
	[[ ! -e ${config_user_file} ]] && echo -e "${Error} Meiyou Faxian ShadowsocksR Pi Zi wen jian，Qing jian cha !" && exit 1
	[[ ! -e ${ssr_folder} ]] && echo -e "${Error} Meiyou Faxian ShadowsocksR  wen jian  jia ，Qing jian cha !" && exit 1
}
Server_Speeder_installation_status(){
	[[ ! -e ${Server_Speeder_file} ]] && echo -e "${Error} Mei you an zhuang Rui su(Server Speeder)，Qing jian cha !" && exit 1
}
LotServer_installation_status(){
	[[ ! -e ${LotServer_file} ]] && echo -e "${Error} Mei you an zhuang LotServer，Qing jian cha !" && exit 1
}
BBR_installation_status(){
	if [[ ! -e ${BBR_file} ]]; then
		echo -e "${Error} Meiyou Faxian BBRJiao Ben，Kai shiXia zai..."
		cd "${file}"
		if ! wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/bbr.sh; then
			echo -e "${Error} BBR Jiao BenXia zai Shi bai !" && exit 1
		else
			echo -e "${Info} BBR Jiao BenXia zai Wan chen !"
			chmod +x bbr.sh
		fi
	fi
}
#  she zhi   fang huo qiang  gui ze 
Add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
	ip6tables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
	ip6tables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
}
Del_iptables(){
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
	ip6tables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	ip6tables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
	fi
}
Set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
		chkconfig --level 2345 iptables on
		chkconfig --level 2345 ip6tables on
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules\n/sbin/ip6tables-restore < /etc/ip6tables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
# 读取  pei zhi xin xi 
Get_IP(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}
Get_User(){
	[[ ! -e ${jq_file} ]] && echo -e "${Error} JQJie xi qi  Bu cun zai ，Qing jian cha !" && exit 1
	port=`${jq_file} '.server_port' ${config_user_file}`
	password=`${jq_file} '.password' ${config_user_file} | sed 's/^.//;s/.$//'`
	method=`${jq_file} '.method' ${config_user_file} | sed 's/^.//;s/.$//'`
	protocol=`${jq_file} '.protocol' ${config_user_file} | sed 's/^.//;s/.$//'`
	obfs=`${jq_file} '.obfs' ${config_user_file} | sed 's/^.//;s/.$//'`
	protocol_param=`${jq_file} '.protocol_param' ${config_user_file} | sed 's/^.//;s/.$//'`
	speed_limit_per_con=`${jq_file} '.speed_limit_per_con' ${config_user_file}`
	speed_limit_per_user=`${jq_file} '.speed_limit_per_user' ${config_user_file}`
	connect_verbose_info=`${jq_file} '.connect_verbose_info' ${config_user_file}`
}
urlsafe_base64(){
	date=$(echo -n "$1"|base64|sed ':a;N;s/\n/ /g;ta'|sed 's/ //g;s/=//g;s/+/-/g;s/\//_/g')
	echo -e "${date}"
}
ss_link_qr(){
	SSbase64=$(urlsafe_base64 "${method}:${password}@${ip}:${port}")
	SSurl="ss://${SSbase64}"
	SSQRcode="http://doub.pw/qr/qr.php?text=${SSurl}"
	ss_link=" SS     lian jie : ${Green_font_prefix}${SSurl}${Font_color_suffix} \n SS   Er wei ma : ${Green_font_prefix}${SSQRcode}${Font_color_suffix}"
}
ssr_link_qr(){
	SSRprotocol=$(echo ${protocol} | sed 's/_compatible//g')
	SSRobfs=$(echo ${obfs} | sed 's/_compatible//g')
	SSRPWDbase64=$(urlsafe_base64 "${password}")
	SSRbase64=$(urlsafe_base64 "${ip}:${port}:${SSRprotocol}:${method}:${SSRobfs}:${SSRPWDbase64}")
	SSRurl="ssr://${SSRbase64}"
	SSRQRcode="http://doub.pw/qr/qr.php?text=${SSRurl}"
	ssr_link=" SSR    lian jie : ${Red_font_prefix}${SSRurl}${Font_color_suffix} \n SSR  Er wei ma : ${Red_font_prefix}${SSRQRcode}${Font_color_suffix} \n "
}
ss_ssr_determine(){
	protocol_suffix=`echo ${protocol} | awk -F "_" '{print $NF}'`
	obfs_suffix=`echo ${obfs} | awk -F "_" '{print $NF}'`
	if [[ ${protocol} = "origin" ]]; then
		if [[ ${obfs} = "plain" ]]; then
			ss_link_qr
			ssr_link=""
		else
			if [[ ${obfs_suffix} != "compatible" ]]; then
				ss_link=""
			else
				ss_link_qr
			fi
		fi
	else
		if [[ ${protocol_suffix} != "compatible" ]]; then
			ss_link=""
		else
			if [[ ${obfs_suffix} != "compatible" ]]; then
				if [[ ${obfs_suffix} = "plain" ]]; then
					ss_link_qr
				else
					ss_link=""
				fi
			else
				ss_link_qr
			fi
		fi
	fi
	ssr_link_qr
}
#  xian shi   pei zhi xin xi 
View_User(){
	SSR_installation_status
	Get_IP
	Get_User
	now_mode=$(cat "${config_user_file}"|grep '"port_password"')
	[[ -z ${protocol_param} ]] && protocol_param="0( wu xian )"
	if [[ -z "${now_mode}" ]]; then
		ss_ssr_determine
		clear && echo "===================================================" && echo
		echo -e " ShadowsocksR zhang hao   pei zhi xin xi ：" && echo
		echo -e " I  P\t    : ${Green_font_prefix}${ip}${Font_color_suffix}"
		echo -e "  port \t    : ${Green_font_prefix}${port}${Font_color_suffix}"
		echo -e "  Pwd \t    : ${Green_font_prefix}${password}${Font_color_suffix}"
		echo -e "  jia mi \t    : ${Green_font_prefix}${method}${Font_color_suffix}"
		echo -e "  xie yi \t    : ${Red_font_prefix}${protocol}${Font_color_suffix}"
		echo -e "  hun xiao \t    : ${Red_font_prefix}${obfs}${Font_color_suffix}"
		echo -e "  she bei shu xian zhi  : ${Green_font_prefix}${protocol_param}${Font_color_suffix}"
		echo -e "  dan xian cheng xian su  : ${Green_font_prefix}${speed_limit_per_con} KB/S${Font_color_suffix}"
		echo -e "  port  zong xian su  : ${Green_font_prefix}${speed_limit_per_user} KB/S${Font_color_suffix}"
		echo -e "${ss_link}"
		echo -e "${ssr_link}"
		echo -e " ${Green_font_prefix}  ti shi : ${Font_color_suffix}
  zai liu lan qi zhong ， da kai  Er wei ma lian jie，jiu ke yi kan dao  Er wei ma tu pian 。
  xie yi  he  hun xiao  hou mian de [ _compatible ]， zhi de shi   jian rong yuan ban ben  xie yi / hun xiao 。"
		echo && echo "==================================================="
	else
		user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
		[[ ${user_total} = "0" ]] && echo -e "${Error} Meiyou Faxian  duo  port  yong hu ，Qing jian cha !" && exit 1
		clear && echo "===================================================" && echo
		echo -e " ShadowsocksR zhang hao   pei zhi xin xi ：" && echo
		echo -e " I  P\t    : ${Green_font_prefix}${ip}${Font_color_suffix}"
		echo -e "  jia mi \t    : ${Green_font_prefix}${method}${Font_color_suffix}"
		echo -e "  xie yi \t    : ${Red_font_prefix}${protocol}${Font_color_suffix}"
		echo -e "  hun xiao \t    : ${Red_font_prefix}${obfs}${Font_color_suffix}"
		echo -e "  she bei shu xian zhi  : ${Green_font_prefix}${protocol_param}${Font_color_suffix}"
		echo -e "  dan xian cheng xian su  : ${Green_font_prefix}${speed_limit_per_con} KB/S${Font_color_suffix}"
		echo -e "  port  zong xian su  : ${Green_font_prefix}${speed_limit_per_user} KB/S${Font_color_suffix}" && echo
		for((integer = ${user_total}; integer >= 1; integer--))
		do
			port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
			password=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $2}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
			ss_ssr_determine
			echo -e ${Separator_1}
			echo -e "  port \t    : ${Green_font_prefix}${port}${Font_color_suffix}"
			echo -e "  Pwd \t    : ${Green_font_prefix}${password}${Font_color_suffix}"
			echo -e "  Pwd \t    : ${Green_font_prefix}${password}${Font_color_suffix}"
			echo -e "${ss_link}"
			echo -e "${ssr_link}"
		done
		echo -e " ${Green_font_prefix}  ti shi : ${Font_color_suffix}
  zai liu lan qi zhong ， da kai  Er wei ma lian jie，jiu ke yi kan dao  Er wei ma tu pian 。
  xie yi  he  hun xiao  hou mian de [ _compatible ]，zhi de shi  jian rong yuan ban ben  xie yi / hun xiao 。"
		echo && echo "==================================================="
	fi
}
#  she zhi   pei zhi xin xi 
Set_config_port(){
	while true
	do
	echo -e " qing shu ru yao she zhi de ShadowsocksR zhang hao   port "
	stty erase '^H' && read -p "( mo ren : 2333):" ssr_port
	[[ -z "$ssr_port" ]] && ssr_port="2333"
	expr ${ssr_port} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_port} -ge 1 ]] && [[ ${ssr_port} -le 65535 ]]; then
			echo && echo ${Separator_1} && echo -e "	 port  : ${Green_font_prefix}${ssr_port}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error}  qing shu ru zheng que de shu zi (1-65535)"
		fi
	else
		echo -e "${Error}  qing shu ru zheng que de shu zi (1-65535)"
	fi
	done
}
Set_config_password(){
	echo " qing shu ru yao she zhi de ShadowsocksR zhang hao   Pwd "
	stty erase '^H' && read -p "( mo ren : doub.io):" ssr_password
	[[ -z "${ssr_password}" ]] && ssr_password="doub.io"
	echo && echo ${Separator_1} && echo -e "	 Pwd  : ${Green_font_prefix}${ssr_password}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_method(){
	echo -e " qing  xuan ze  yao she zhi de ShadowsocksR zhang hao   jia mi  fang shi 
 ${Green_font_prefix} 1.${Font_color_suffix} none
 ${Tip}  ru guo  shi yong  auth_chain_a  xie yi ， qing  jia mi  fang shi  xuan ze  none， hun xiao  sui yi ( jian yi  plain)
 
 ${Green_font_prefix} 2.${Font_color_suffix} rc4
 ${Green_font_prefix} 3.${Font_color_suffix} rc4-md5
 ${Green_font_prefix} 4.${Font_color_suffix} rc4-md5-6
 
 ${Green_font_prefix} 5.${Font_color_suffix} aes-128-ctr
 ${Green_font_prefix} 6.${Font_color_suffix} aes-192-ctr
 ${Green_font_prefix} 7.${Font_color_suffix} aes-256-ctr
 
 ${Green_font_prefix} 8.${Font_color_suffix} aes-128-cfb
 ${Green_font_prefix} 9.${Font_color_suffix} aes-192-cfb
 ${Green_font_prefix}10.${Font_color_suffix} aes-256-cfb
 
 ${Green_font_prefix}11.${Font_color_suffix} aes-128-cfb8
 ${Green_font_prefix}12.${Font_color_suffix} aes-192-cfb8
 ${Green_font_prefix}13.${Font_color_suffix} aes-256-cfb8
 
 ${Green_font_prefix}14.${Font_color_suffix} salsa20
 ${Green_font_prefix}15.${Font_color_suffix} chacha20
 ${Green_font_prefix}16.${Font_color_suffix} chacha20-ietf
 ${Tip} salsa20/chacha20-* xi lie  jia mi  fang shi ， xu yao e wai  Install  yi lai  libsodium ，fou ze hui wu fa qi dong ShadowsocksR !" && echo
	stty erase '^H' && read -p "( mo ren : 5. aes-128-ctr):" ssr_method
	[[ -z "${ssr_method}" ]] && ssr_method="5"
	if [[ ${ssr_method} == "1" ]]; then
		ssr_method="none"
	elif [[ ${ssr_method} == "2" ]]; then
		ssr_method="rc4"
	elif [[ ${ssr_method} == "3" ]]; then
		ssr_method="rc4-md5"
	elif [[ ${ssr_method} == "4" ]]; then
		ssr_method="rc4-md5-6"
	elif [[ ${ssr_method} == "5" ]]; then
		ssr_method="aes-128-ctr"
	elif [[ ${ssr_method} == "6" ]]; then
		ssr_method="aes-192-ctr"
	elif [[ ${ssr_method} == "7" ]]; then
		ssr_method="aes-256-ctr"
	elif [[ ${ssr_method} == "8" ]]; then
		ssr_method="aes-128-cfb"
	elif [[ ${ssr_method} == "9" ]]; then
		ssr_method="aes-192-cfb"
	elif [[ ${ssr_method} == "10" ]]; then
		ssr_method="aes-256-cfb"
	elif [[ ${ssr_method} == "11" ]]; then
		ssr_method="aes-128-cfb8"
	elif [[ ${ssr_method} == "12" ]]; then
		ssr_method="aes-192-cfb8"
	elif [[ ${ssr_method} == "13" ]]; then
		ssr_method="aes-256-cfb8"
	elif [[ ${ssr_method} == "14" ]]; then
		ssr_method="salsa20"
	elif [[ ${ssr_method} == "15" ]]; then
		ssr_method="chacha20"
	elif [[ ${ssr_method} == "16" ]]; then
		ssr_method="chacha20-ietf"
	else
		ssr_method="aes-128-ctr"
	fi
	echo && echo ${Separator_1} && echo -e "	 jia mi  : ${Green_font_prefix}${ssr_method}${Font_color_suffix}" && echo ${Separator_1} && echo
}
Set_config_protocol(){
	echo -e " qing  xuan ze  yao she zhi de ShadowsocksR zhang hao   xie yi  cha jian 
 ${Green_font_prefix}1.${Font_color_suffix} origin
 ${Green_font_prefix}2.${Font_color_suffix} auth_sha1_v4
 ${Green_font_prefix}3.${Font_color_suffix} auth_aes128_md5
 ${Green_font_prefix}4.${Font_color_suffix} auth_aes128_sha1
 ${Green_font_prefix}5.${Font_color_suffix} auth_chain_a
 ${Green_font_prefix}6.${Font_color_suffix} auth_chain_b
 ${Tip}  ru guo  shi yong  auth_chain_a  xie yi ， qing  jia mi  fang shi  xuan ze  none， hun xiao  sui yi ( jian yi  plain)" && echo
	stty erase '^H' && read -p "( mo ren : 2. auth_sha1_v4):" ssr_protocol
	[[ -z "${ssr_protocol}" ]] && ssr_protocol="2"
	if [[ ${ssr_protocol} == "1" ]]; then
		ssr_protocol="origin"
	elif [[ ${ssr_protocol} == "2" ]]; then
		ssr_protocol="auth_sha1_v4"
	elif [[ ${ssr_protocol} == "3" ]]; then
		ssr_protocol="auth_aes128_md5"
	elif [[ ${ssr_protocol} == "4" ]]; then
		ssr_protocol="auth_aes128_sha1"
	elif [[ ${ssr_protocol} == "5" ]]; then
		ssr_protocol="auth_chain_a"
	elif [[ ${ssr_protocol} == "6" ]]; then
		ssr_protocol="auth_chain_b"
	else
		ssr_protocol="auth_sha1_v4"
	fi
	echo && echo ${Separator_1} && echo -e "	 xie yi  : ${Green_font_prefix}${ssr_protocol}${Font_color_suffix}" && echo ${Separator_1} && echo
	if [[ ${ssr_protocol} != "origin" ]]; then
		if [[ ${ssr_protocol} == "auth_sha1_v4" ]]; then
			stty erase '^H' && read -p " shi fou  she zhi   xie yi  cha jian  jian rong yuan ban ben (_compatible)？[Y/n]" ssr_protocol_yn
			[[ -z "${ssr_protocol_yn}" ]] && ssr_protocol_yn="y"
			[[ $ssr_protocol_yn == [Yy] ]] && ssr_protocol=${ssr_protocol}"_compatible"
			echo
		fi
	fi
}
Set_config_obfs(){
	echo -e " qing  xuan ze  yao she zhi de ShadowsocksR zhang hao   hun xiao  cha jian 
 ${Green_font_prefix}1.${Font_color_suffix} plain
 ${Green_font_prefix}2.${Font_color_suffix} http_simple
 ${Green_font_prefix}3.${Font_color_suffix} http_post
 ${Green_font_prefix}4.${Font_color_suffix} random_head
 ${Green_font_prefix}5.${Font_color_suffix} tls1.2_ticket_auth
 ${Tip}  ru guo  shi yong  ShadowsocksR 加速游戏， qing  xuan ze   hun xiao  jian rong yuan ban ben  huo  plain  hun xiao ， rang hou  ke hu duan  xuan ze  plain，fou ze hui tian jia yan chi !" && echo
	stty erase '^H' && read -p "( mo ren : 5. tls1.2_ticket_auth):" ssr_obfs
	[[ -z "${ssr_obfs}" ]] && ssr_obfs="5"
	if [[ ${ssr_obfs} == "1" ]]; then
		ssr_obfs="plain"
	elif [[ ${ssr_obfs} == "2" ]]; then
		ssr_obfs="http_simple"
	elif [[ ${ssr_obfs} == "3" ]]; then
		ssr_obfs="http_post"
	elif [[ ${ssr_obfs} == "4" ]]; then
		ssr_obfs="random_head"
	elif [[ ${ssr_obfs} == "5" ]]; then
		ssr_obfs="tls1.2_ticket_auth"
	else
		ssr_obfs="tls1.2_ticket_auth"
	fi
	echo && echo ${Separator_1} && echo -e "	 hun xiao  : ${Green_font_prefix}${ssr_obfs}${Font_color_suffix}" && echo ${Separator_1} && echo
	if [[ ${ssr_obfs} != "plain" ]]; then
			stty erase '^H' && read -p " shi fou  she zhi   hun xiao  cha jian jian rong yuan ban ben (_compatible)？[Y/n]" ssr_obfs_yn
			[[ -z "${ssr_obfs_yn}" ]] && ssr_obfs_yn="y"
			[[ $ssr_obfs_yn == [Yy] ]] && ssr_obfs=${ssr_obfs}"_compatible"
			echo
	fi
}
Set_config_protocol_param(){
	while true
	do
	echo -e " qing shu ru yao she zhi de ShadowsocksR zhang hao  xian zhi de shu (${Green_font_prefix} auth_*  xi lie  xie yi  bu jian rong yuan ban ben cai you xiao  ${Font_color_suffix})"
	echo -e "${Tip}  she bei shu xian zhi ： mei  ge  port tong yi shi jian neng  lian jie de ke hu duan shu liang ( duo  port  mo shi ， mei  ge  port dou shi du li  ji suan )， jian yi  zui shao  2 ge 。"
	stty erase '^H' && read -p "( mo ren :  wu xian ):" ssr_protocol_param
	[[ -z "$ssr_protocol_param" ]] && ssr_protocol_param="" && echo && break
	expr ${ssr_protocol_param} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_protocol_param} -ge 1 ]] && [[ ${ssr_protocol_param} -le 9999 ]]; then
			echo && echo ${Separator_1} && echo -e "	 she bei shu xian zhi  : ${Green_font_prefix}${ssr_protocol_param}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error}  qing shu ru zheng que de shu zi (1-9999)"
		fi
	else
		echo -e "${Error}  qing shu ru zheng que de shu zi (1-9999)"
	fi
	done
}
Set_config_speed_limit_per_con(){
	while true
	do
	echo -e " qing shu ru yao she zhi de  mei  ge  port   dan xian cheng xian shu shang xian ( dan 位：KB/S)"
	echo -e "${Tip}  dan xian cheng xian su ： mei  ge  port   dan xian cheng xian shu shang xian， duo xian cheng ji wu xiao 。"
	stty erase '^H' && read -p "( mo ren :  wu xian ):" ssr_speed_limit_per_con
	[[ -z "$ssr_speed_limit_per_con" ]] && ssr_speed_limit_per_con=0 && echo && break
	expr ${ssr_speed_limit_per_con} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_speed_limit_per_con} -ge 1 ]] && [[ ${ssr_speed_limit_per_con} -le 131072 ]]; then
			echo && echo ${Separator_1} && echo -e "	 dan xian cheng xian su  : ${Green_font_prefix}${ssr_speed_limit_per_con} KB/S${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error}  qing shu ru zheng que de shu zi (1-131072)"
		fi
	else
		echo -e "${Error}  qing shu ru zheng que de shu zi (1-131072)"
	fi
	done
}
Set_config_speed_limit_per_user(){
	while true
	do
	echo
	echo -e " qing shu ru yao she zhi de mei  ge  port  zong su du  xian shu shang xian( dan 位：KB/S)"
	echo -e "${Tip}  port  zong xian su ：mei ge  port  zong su du  xian shu shang xian， dan  ge  port 整体限速。"
	stty erase '^H' && read -p "( mo ren :  wu xian ):" ssr_speed_limit_per_user
	[[ -z "$ssr_speed_limit_per_user" ]] && ssr_speed_limit_per_user=0 && echo && break
	expr ${ssr_speed_limit_per_user} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${ssr_speed_limit_per_user} -ge 1 ]] && [[ ${ssr_speed_limit_per_user} -le 131072 ]]; then
			echo && echo ${Separator_1} && echo -e "	 port  zong xian su  : ${Green_font_prefix}${ssr_speed_limit_per_user} KB/S${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error}  qing shu ru zheng que de shu zi (1-131072)"
		fi
	else
		echo -e "${Error}  qing shu ru zheng que de shu zi (1-131072)"
	fi
	done
}
Set_config_all(){
	Set_config_port
	Set_config_password
	Set_config_method
	Set_config_protocol
	Set_config_obfs
	Set_config_protocol_param
	Set_config_speed_limit_per_con
	Set_config_speed_limit_per_user
}
#  xiu gai   pei zhi xin xi 
Modify_config_port(){
	sed -i 's/"server_port": '"$(echo ${port})"'/"server_port": '"$(echo ${ssr_port})"'/g' ${config_user_file}
}
Modify_config_password(){
	sed -i 's/"password": "'"$(echo ${password})"'"/"password": "'"$(echo ${ssr_password})"'"/g' ${config_user_file}
}
Modify_config_method(){
	sed -i 's/"method": "'"$(echo ${method})"'"/"method": "'"$(echo ${ssr_method})"'"/g' ${config_user_file}
}
Modify_config_protocol(){
	sed -i 's/"protocol": "'"$(echo ${protocol})"'"/"protocol": "'"$(echo ${ssr_protocol})"'"/g' ${config_user_file}
}
Modify_config_obfs(){
	sed -i 's/"obfs": "'"$(echo ${obfs})"'"/"obfs": "'"$(echo ${ssr_obfs})"'"/g' ${config_user_file}
}
Modify_config_protocol_param(){
	sed -i 's/"protocol_param": "'"$(echo ${protocol_param})"'"/"protocol_param": "'"$(echo ${ssr_protocol_param})"'"/g' ${config_user_file}
}
Modify_config_speed_limit_per_con(){
	sed -i 's/"speed_limit_per_con": '"$(echo ${speed_limit_per_con})"'/"speed_limit_per_con": '"$(echo ${ssr_speed_limit_per_con})"'/g' ${config_user_file}
}
Modify_config_speed_limit_per_user(){
	sed -i 's/"speed_limit_per_user": '"$(echo ${speed_limit_per_user})"'/"speed_limit_per_user": '"$(echo ${ssr_speed_limit_per_user})"'/g' ${config_user_file}
}
Modify_config_connect_verbose_info(){
	sed -i 's/"connect_verbose_info": '"$(echo ${connect_verbose_info})"'/"connect_verbose_info": '"$(echo ${ssr_connect_verbose_info})"'/g' ${config_user_file}
}
Modify_config_all(){
	Modify_config_port
	Modify_config_password
	Modify_config_method
	Modify_config_protocol
	Modify_config_obfs
	Modify_config_protocol_param
	Modify_config_speed_limit_per_con
	Modify_config_speed_limit_per_user
}
Modify_config_port_many(){
	sed -i 's/"'"$(echo ${port})"'":/"'"$(echo ${ssr_port})"'":/g' ${config_user_file}
}
Modify_config_password_many(){
	sed -i 's/"'"$(echo ${password})"'"/"'"$(echo ${ssr_password})"'"/g' ${config_user_file}
}
#  xie ru   pei zhi xin xi 
Write_configuration(){
	cat > ${config_user_file}<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "server_port": ${ssr_port},
    "local_address": "127.0.0.1",
    "local_port": 1080,

    "password": "${ssr_password}",
    "method": "${ssr_method}",
    "protocol": "${ssr_protocol}",
    "protocol_param": "${ssr_protocol_param}",
    "obfs": "${ssr_obfs}",
    "obfs_param": "",
    "speed_limit_per_con": ${ssr_speed_limit_per_con},
    "speed_limit_per_user": ${ssr_speed_limit_per_user},

    "additional_ports" : {},
    "timeout": 120,
    "udp_timeout": 60,
    "dns_ipv6": false,
    "connect_verbose_info": 0,
    "redirect": "",
    "fast_open": false
}
EOF
}
Write_configuration_many(){
	cat > ${config_user_file}<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "local_address": "127.0.0.1",
    "local_port": 1080,

    "port_password":{
        "${ssr_port}":"${ssr_password}"
    },
    "method": "${ssr_method}",
    "protocol": "${ssr_protocol}",
    "protocol_param": "${ssr_protocol_param}",
    "obfs": "${ssr_obfs}",
    "obfs_param": "",
    "speed_limit_per_con": ${ssr_speed_limit_per_con},
    "speed_limit_per_user": ${ssr_speed_limit_per_user},

    "additional_ports" : {},
    "timeout": 120,
    "udp_timeout": 60,
    "dns_ipv6": false,
    "connect_verbose_info": 0,
    "redirect": "",
    "fast_open": false
}
EOF
}
Check_python(){
	python_ver=`python -h`
	if [[ -z ${python_ver} ]]; then
		echo -e "${Info} Mei you an zhuangPython，Kai shi Install ..."
		if [[ ${release} == "centos" ]]; then
			yum install -y python
		else
			apt-get install -y python
		fi
	fi
}
Centos_yum(){
	yum update
	cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
	if [[ $? = 0 ]]; then
		yum install -y vim unzip net-tools
	else
		yum install -y vim unzip
	fi
}
Debian_apt(){
	apt-get update
	cat /etc/issue |grep 9\..*>/dev/null
	if [[ $? = 0 ]]; then
		apt-get install -y vim unzip net-tools
	else
		apt-get install -y vim unzip
	fi
}
# Xia zai ShadowsocksR
Download_SSR(){
	cd "/usr/local/"
	wget -N --no-check-certificate "https://github.com/ToyoDAdoubi/shadowsocksr/archive/manyuser.zip"
	#git config --global http.sslVerify false
	#env GIT_SSL_NO_VERIFY=true git clone -b manyuser https://github.com/ToyoDAdoubi/shadowsocksr.git
	#[[ ! -e ${ssr_folder} ]] && echo -e "${Error} ShadowsocksR fu wu duan  Xia zai Shi bai !" && exit 1
	[[ ! -e "manyuser.zip" ]] && echo -e "${Error} ShadowsocksR fu wu duan   ya suo bao  Xia zai Shi bai !" && rm -rf manyuser.zip && exit 1
	unzip "manyuser.zip"
	[[ ! -e "/usr/local/shadowsocksr-manyuser/" ]] && echo -e "${Error} ShadowsocksR fu wu duan   jie ya  Shi bai !" && rm -rf manyuser.zip && exit 1
	mv "/usr/local/shadowsocksr-manyuser/" "/usr/local/shadowsocksr/"
	[[ ! -e "/usr/local/shadowsocksr/" ]] && echo -e "${Error} ShadowsocksR fu wu duan   chong mingm  Shi bai !" && rm -rf manyuser.zip && rm -rf "/usr/local/shadowsocksr-manyuser/" && exit 1
	rm -rf manyuser.zip
	[[ -e ${config_folder} ]] && rm -rf ${config_folder}
	mkdir ${config_folder}
	[[ ! -e ${config_folder} ]] && echo -e "${Error} ShadowsocksRPi Zi wen jian的 wen jian  jia   jian li  Shi bai !" && exit 1
	echo -e "${Info} ShadowsocksR fu wu duan  Xia zai Wan chen !"
}
Service_SSR(){
	if [[ ${release} = "centos" ]]; then
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/other/ssr_centos -O /etc/init.d/ssr; then
			echo -e "${Error} ShadowsocksR fu wu   guan li Jiao BenXia zai Shi bai !" && exit 1
		fi
		chmod +x /etc/init.d/ssr
		chkconfig --add ssr
		chkconfig ssr on
	else
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/other/ssr_debian -O /etc/init.d/ssr; then
			echo -e "${Error} ShadowsocksR fu wu   guan li Jiao BenXia zai Shi bai !" && exit 1
		fi
		chmod +x /etc/init.d/ssr
		update-rc.d -f ssr defaults
	fi
	echo -e "${Info} ShadowsocksR fu wu   guan li Jiao BenXia zai Wan chen !"
}
#  Install  JQJie xi qi
JQ_install(){
	if [[ ! -e ${jq_file} ]]; then
		cd "${ssr_folder}"
		if [[ ${bit} = "x86_64" ]]; then
			mv "jq-linux64" "jq"
			#wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" -O ${jq_file}
		else
			mv "jq-linux32" "jq"
			#wget --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux32" -O ${jq_file}
		fi
		[[ ! -e ${jq_file} ]] && echo -e "${Error} JQJie xi qi  chong mingm  Shi bai，Qing jian cha !" && exit 1
		chmod +x ${jq_file}
		echo -e "${Info} JQJie xi qi  Install  Wan chen， ji xu ..." 
	else
		echo -e "${Info} JQJie xi qi  yi  Install ， ji xu ..."
	fi
}
#  Install   yi lai 
Installation_dependency(){
	if [[ ${release} == "centos" ]]; then
		Centos_yum
	else
		Debian_apt
	fi
	[[ ! -e "/usr/bin/unzip" ]] && echo -e "${Error}  yi lai  unzip( jie ya  ya suo bao )  Install  Shi bai， duo ban shi ruan jian bao yuan de wen ti ，Qing jian cha !" && exit 1
	Check_python
	#echo "nameserver 8.8.8.8" > /etc/resolv.conf
	#echo "nameserver 8.8.4.4" >> /etc/resolv.conf
	cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}
Install_SSR(){
	check_root
	[[ -e ${config_user_file} ]] && echo -e "${Error} ShadowsocksR Pi Zi wen jian yi  cun zai ，Qing jian cha(  ru  Install  Shi bai huo zhe  cun zai  old  ban ben ， qing  xian  unInstall  ) !" && exit 1
	[[ -e ${ssr_folder} ]] && echo -e "${Error} ShadowsocksR  wen jian  jia  yi  cun zai ，Qing jian cha(  ru  Install  Shi bai huo zhe  cun zai  old  ban ben ， qing  xian  unInstall  ) !" && exit 1
	echo -e "${Info} Kai shi she zhi  ShadowsocksR zhang hao  pei zhi ..."
	Set_config_all
	echo -e "${Info} Kai shi Install / pei zhi  ShadowsocksR yi lai ..."
	Installation_dependency
	echo -e "${Info} Kai shiXia zai/ Install  ShadowsocksR wen jian ..."
	Download_SSR
	echo -e "${Info} Kai shiXia zai/ Install  ShadowsocksR fu wu Jiao Ben(init)..."
	Service_SSR
	echo -e "${Info} Kai shiXia zai/ Install  JSNOJie xi qi JQ..."
	JQ_install
	echo -e "${Info} Kai shi xie ru  ShadowsocksRPi Zi wen jian..."
	Write_configuration
	echo -e "${Info} Kai shi she zhi  iptables fang huo qiang ..."
	Set_iptables
	echo -e "${Info} Kai shi tian jia  iptables fang huo qiang  gui ze ..."
	Add_iptables
	echo -e "${Info} Kai shi bao cun  iptables fang huo qiang  gui ze ..."
	Save_iptables
	echo -e "${Info}  suo you bu zou   Install  wan bi ，Kai shi qi dong  ShadowsocksR fu wu duan ..."
	Start_SSR
}
Update_SSR(){
	SSR_installation_status
	echo -e "yin po wa zang ting  update ShadowsocksR fu wu duan ，suo yi ci gong neng lin shi jin yong。"
	#cd ${ssr_folder}
	#git pull
	#Restart_SSR
}
Uninstall_SSR(){
	[[ ! -e ${config_user_file} ]] && [[ ! -e ${ssr_folder} ]] && echo -e "${Error} Mei you an zhuang ShadowsocksR，Qing jian cha !" && exit 1
	echo " que ding yao   unInstall ShadowsocksR？[y/N]" && echo
	stty erase '^H' && read -p "( mo ren : n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z "${PID}" ]] && kill -9 ${PID}
		if [[ -z "${now_mode}" ]]; then
			port=`${jq_file} '.server_port' ${config_user_file}`
			Del_iptables
		else
			user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
			for((integer = 1; integer <= ${user_total}; integer++))
			do
				port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
				Del_iptables
			done
		fi
		if [[ ${release} = "centos" ]]; then
			chkconfig --del ssr
		else
			update-rc.d -f ssr remove
		fi
		rm -rf ${ssr_folder} && rm -rf ${config_folder} && rm -rf /etc/init.d/ssr
		echo && echo " ShadowsocksR  unInstall  Wan chen !" && echo
	else
		echo && echo "  unInstall  yi  qu xiao ..." && echo
	fi
}
Check_Libsodium_ver(){
	echo -e "${Info} Kai shi huo qu  libsodium  zui  new  ban ben ..."
	Libsodiumr_ver=$(wget -qO- "https://github.com/jedisct1/libsodium/tags"|grep "/jedisct1/libsodium/releases/tag/"|head -1|sed -r 's/.*tag\/(.+)\">.*/\1/')
	[[ -z ${Libsodiumr_ver} ]] && Libsodiumr_ver=${Libsodiumr_ver_backup}
	echo -e "${Info} libsodium  zui  new  ban ben 为 ${Green_font_prefix}${Libsodiumr_ver}${Font_color_suffix} !"
}
Install_Libsodium(){
	if [[ -e ${Libsodiumr_file} ]]; then
		echo -e "${Error} libsodium  yi  Install  ,  shi fou  fu gai  Install ( update )？[y/N]"
		stty erase '^H' && read -p "( mo ren : n):" yn
		[[ -z ${yn} ]] && yn="n"
		if [[ ${yn} == [Nn] ]]; then
			echo " yi  qu xiao ..." && exit 1
		fi
	else
		echo -e "${Info} libsodium  no  Install ，Kai shi Install ..."
	fi
	Check_Libsodium_ver
	if [[ ${release} == "centos" ]]; then
		yum update
		echo -e "${Info}  Install  yi lai ..."
		yum -y groupinstall "Development Tools"
		echo -e "${Info} Xia zai..."
		wget  --no-check-certificate -N "https://github.com/jedisct1/libsodium/releases/download/${Libsodiumr_ver}/libsodium-${Libsodiumr_ver}.tar.gz"
		echo -e "${Info}  jie ya ..."
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		echo -e "${Info}  bian yi  Install ..."
		./configure --disable-maintainer-mode && make -j2 && make install
		echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	else
		apt-get update
		echo -e "${Info}  Install  yi lai ..."
		apt-get install -y build-essential
		echo -e "${Info} Xia zai..."
		wget  --no-check-certificate -N "https://github.com/jedisct1/libsodium/releases/download/${Libsodiumr_ver}/libsodium-${Libsodiumr_ver}.tar.gz"
		echo -e "${Info}  jie ya ..."
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		echo -e "${Info}  bian yi  Install ..."
		./configure --disable-maintainer-mode && make -j2 && make install
	fi
	ldconfig
	cd .. && rm -rf libsodium-${Libsodiumr_ver}.tar.gz && rm -rf libsodium-${Libsodiumr_ver}
	[[ ! -e ${Libsodiumr_file} ]] && echo -e "${Error} libsodium  Install  Shi bai !" && exit 1
	echo && echo -e "${Info} libsodium  Install  cheng gong  !" && echo
}
#  xian shi   lian jie  xin xi 
debian_View_user_connection_info(){
	format_1=$1
	if [[ -z "${now_mode}" ]]; then
		now_mode=" dan  port " && user_total="1"
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |wc -l`
		user_port=`${jq_file} '.server_port' ${config_user_file}`
		user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |grep ":${user_port} " |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u`
		if [[ -z ${user_IP_1} ]]; then
			user_IP_total="0"
		else
			user_IP_total=`echo -e "${user_IP_1}"|wc -l`
			if [[ ${format_1} == "IP_address" ]]; then
				get_IP_address
			else
				user_IP=`echo -e "\n${user_IP_1}"`
			fi
		fi
		user_list_all=" port : ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t  lian jieIP zong shu : ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t  dang qian  lian jieIP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
		user_IP=""
		echo -e " dang qian mo shi : ${Green_background_prefix} "${now_mode}" ${Font_color_suffix}  lian jieIP zong shu : ${Green_background_prefix} "${IP_total}" ${Font_color_suffix}"
		echo -e "${user_list_all}"
	else
		now_mode=" duo  port " && user_total=`${jq_file} '.port_password' ${config_user_file} |sed '$d;1d' | wc -l`
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u |wc -l`
		user_list_all=""
		for((integer = ${user_total}; integer >= 1; integer--))
		do
			user_port=`${jq_file} '.port_password' ${config_user_file} |sed '$d;1d' |awk -F ":" '{print $1}' |sed -n "${integer}p" |sed -r 's/.*\"(.+)\".*/\1/'`
			user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp6' |grep "${user_port}" |awk '{print $5}' |awk -F ":" '{print $1}' |sort -u`
			if [[ -z ${user_IP_1} ]]; then
				user_IP_total="0"
			else
				user_IP_total=`echo -e "${user_IP_1}"|wc -l`
				if [[ ${format_1} == "IP_address" ]]; then
					get_IP_address
				else
					user_IP=`echo -e "\n${user_IP_1}"`
				fi
			fi
			user_list_all=${user_list_all}" port : ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t  lian jieIP zong shu : ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t  dang qian  lian jieIP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
			user_IP=""
		done
		echo -e " dang qian mo shi : ${Green_background_prefix} "${now_mode}" ${Font_color_suffix}  yong hu  zong shu : ${Green_background_prefix} "${user_total}" ${Font_color_suffix}  lian jieIP zong shu : ${Green_background_prefix} "${IP_total}" ${Font_color_suffix} "
		echo -e "${user_list_all}"
	fi
}
centos_View_user_connection_info(){
	format_1=$1
	if [[ -z "${now_mode}" ]]; then
		now_mode=" dan  port " && user_total="1"
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u |wc -l`
		user_port=`${jq_file} '.server_port' ${config_user_file}`
		user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep ":${user_port} " | grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u`
		if [[ -z ${user_IP_1} ]]; then
			user_IP_total="0"
		else
			user_IP_total=`echo -e "${user_IP_1}"|wc -l`
			if [[ ${format_1} == "IP_address" ]]; then
				get_IP_address
			else
				user_IP=`echo -e "\n${user_IP_1}"`
			fi
		fi
		user_list_all=" port : ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t  lian jieIP zong shu : ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t  dang qian  lian jieIP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
		user_IP=""
		echo -e " dang qian mo shi : ${Green_background_prefix} "${now_mode}" ${Font_color_suffix}  lian jieIP zong shu : ${Green_background_prefix} "${IP_total}" ${Font_color_suffix}"
		echo -e "${user_list_all}"
	else
		now_mode=" duo  port " && user_total=`${jq_file} '.port_password' ${config_user_file} |sed '$d;1d' | wc -l`
		IP_total=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' | grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u |wc -l`
		user_list_all=""
		for((integer = 1; integer <= ${user_total}; integer++))
		do
			user_port=`${jq_file} '.port_password' ${config_user_file} |sed '$d;1d' |awk -F ":" '{print $1}' |sed -n "${integer}p" |sed -r 's/.*\"(.+)\".*/\1/'`
			user_IP_1=`netstat -anp |grep 'ESTABLISHED' |grep 'python' |grep 'tcp' |grep "${user_port}"|grep '::ffff:' |awk '{print $5}' |awk -F ":" '{print $4}' |sort -u`
			if [[ -z ${user_IP_1} ]]; then
				user_IP_total="0"
			else
				user_IP_total=`echo -e "${user_IP_1}"|wc -l`
				if [[ ${format_1} == "IP_address" ]]; then
					get_IP_address
				else
					user_IP=`echo -e "\n${user_IP_1}"`
				fi
			fi
			user_list_all=${user_list_all}" port : ${Green_font_prefix}"${user_port}"${Font_color_suffix}\t  lian jieIP zong shu : ${Green_font_prefix}"${user_IP_total}"${Font_color_suffix}\t  dang qian  lian jieIP: ${Green_font_prefix}${user_IP}${Font_color_suffix}\n"
			user_IP=""
		done
		echo -e " dang qian mo shi : ${Green_background_prefix} "${now_mode}" ${Font_color_suffix}  yong hu  zong shu : ${Green_background_prefix} "${user_total}" ${Font_color_suffix}  lian jieIP zong shu : ${Green_background_prefix} "${IP_total}" ${Font_color_suffix} "
		echo -e "${user_list_all}"
	fi
}
View_user_connection_info(){
	SSR_installation_status
	echo && echo -e " qing  xuan ze yao  xian shi de ge shi ：
 ${Green_font_prefix}1.${Font_color_suffix}  xian shi  IP  ge shi 
 ${Green_font_prefix}2.${Font_color_suffix}  xian shi  IP+IP gui shu di   ge shi " && echo
	stty erase '^H' && read -p "( mo ren : 1):" ssr_connection_info
	[[ -z "${ssr_connection_info}" ]] && ssr_connection_info="1"
	if [[ ${ssr_connection_info} == "1" ]]; then
		View_user_connection_info_1 ""
	elif [[ ${ssr_connection_info} == "2" ]]; then
		echo -e "${Tip} jian che IP gui shu di (ipip.net)， ru guo IP jiao duo ，ke neng shi jian hui bi jiao chang"
		View_user_connection_info_1 "IP_address"
	else
		echo -e "${Error}  qing shu ru zheng que de shu zi (1-2)" && exit 1
	fi
}
View_user_connection_info_1(){
	format=$1
	if [[ ${release} = "centos" ]]; then
		cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
		if [[ $? = 0 ]]; then
			debian_View_user_connection_info "$format"
		else
			centos_View_user_connection_info "$format"
		fi
	else
		debian_View_user_connection_info "$format"
	fi
}
get_IP_address(){
	#echo "user_IP_1=${user_IP_1}"
	if [[ ! -z ${user_IP_1} ]]; then
	#echo "user_IP_total=${user_IP_total}"
		for((integer_1 = ${user_IP_total}; integer_1 >= 1; integer_1--))
		do
			IP=`echo "${user_IP_1}" |sed -n "$integer_1"p`
			#echo "IP=${IP}"
			IP_address=`wget -qO- -t1 -T2 http://freeapi.ipip.net/${IP}|sed 's/\"//g;s/,//g;s/\[//g;s/\]//g'`
			#echo "IP_address=${IP_address}"
			user_IP="${user_IP}\n${IP}(${IP_address})"
			#echo "user_IP=${user_IP}"
			sleep 1s
		done
	fi
}
#  xiu gai   yong hu  pei zhi 
Modify_Config(){
	SSR_installation_status
	if [[ -z "${now_mode}" ]]; then
		echo && echo -e " dang qian mo shi :  dan  port ， ni yao zuo shen me ？
 ${Green_font_prefix}1.${Font_color_suffix}  xiu gai   yong hu  port 
 ${Green_font_prefix}2.${Font_color_suffix}  xiu gai   yong hu  Pwd 
 ${Green_font_prefix}3.${Font_color_suffix}  xiu gai   jia mi  fang shi 
 ${Green_font_prefix}4.${Font_color_suffix}  xiu gai   xie yi  cha jian 
 ${Green_font_prefix}5.${Font_color_suffix}  xiu gai   hun xiao  cha jian 
 ${Green_font_prefix}6.${Font_color_suffix}  xiu gai   she bei shu xian zhi 
 ${Green_font_prefix}7.${Font_color_suffix}  xiu gai   dan xian cheng xian su 
 ${Green_font_prefix}8.${Font_color_suffix}  xiu gai   port  zong xian su 
 ${Green_font_prefix}9.${Font_color_suffix}  xiu gai   quan bu pei zhi " && echo
		stty erase '^H' && read -p "( mo ren :  qu xiao ):" ssr_modify
		[[ -z "${ssr_modify}" ]] && echo " yi  qu xiao ..." && exit 1
		Get_User
		if [[ ${ssr_modify} == "1" ]]; then
			Set_config_port
			Modify_config_port
			Add_iptables
			Del_iptables
			Save_iptables
		elif [[ ${ssr_modify} == "2" ]]; then
			Set_config_password
			Modify_config_password
		elif [[ ${ssr_modify} == "3" ]]; then
			Set_config_method
			Modify_config_method
		elif [[ ${ssr_modify} == "4" ]]; then
			Set_config_protocol
			Modify_config_protocol
		elif [[ ${ssr_modify} == "5" ]]; then
			Set_config_obfs
			Modify_config_obfs
		elif [[ ${ssr_modify} == "6" ]]; then
			Set_config_protocol_param
			Modify_config_protocol_param
		elif [[ ${ssr_modify} == "7" ]]; then
			Set_config_speed_limit_per_con
			Modify_config_speed_limit_per_con
		elif [[ ${ssr_modify} == "8" ]]; then
			Set_config_speed_limit_per_user
			Modify_config_speed_limit_per_user
		elif [[ ${ssr_modify} == "9" ]]; then
			Set_config_all
			Modify_config_all
		else
			echo -e "${Error}  qing shu ru zheng que de shu zi (1-9)" && exit 1
		fi
	else
		echo && echo -e " dang qian mo shi :  duo  port ， ni yao zuo shen me ？
 ${Green_font_prefix}1.${Font_color_suffix}   tian jia   yong hu  pei zhi 
 ${Green_font_prefix}2.${Font_color_suffix}   shan chu   yong hu  pei zhi 
 ${Green_font_prefix}3.${Font_color_suffix}   xiu gai   yong hu  pei zhi 
——————————
 ${Green_font_prefix}4.${Font_color_suffix}   xiu gai   jia mi  fang shi 
 ${Green_font_prefix}5.${Font_color_suffix}   xiu gai   xie yi  cha jian 
 ${Green_font_prefix}6.${Font_color_suffix}   xiu gai   hun xiao  cha jian 
 ${Green_font_prefix}7.${Font_color_suffix}   xiu gai   she bei shu xian zhi 
 ${Green_font_prefix}8.${Font_color_suffix}   xiu gai   dan xian cheng xian su 
 ${Green_font_prefix}9.${Font_color_suffix}   xiu gai   port  zong xian su 
 ${Green_font_prefix}10.${Font_color_suffix}  xiu gai   quan bu pei zhi " && echo
		stty erase '^H' && read -p "( mo ren :  qu xiao ):" ssr_modify
		[[ -z "${ssr_modify}" ]] && echo " yi  qu xiao ..." && exit 1
		Get_User
		if [[ ${ssr_modify} == "1" ]]; then
			Add_multi_port_user
		elif [[ ${ssr_modify} == "2" ]]; then
			Del_multi_port_user
		elif [[ ${ssr_modify} == "3" ]]; then
			Modify_multi_port_user
		elif [[ ${ssr_modify} == "4" ]]; then
			Set_config_method
			Modify_config_method
		elif [[ ${ssr_modify} == "5" ]]; then
			Set_config_protocol
			Modify_config_protocol
		elif [[ ${ssr_modify} == "6" ]]; then
			Set_config_obfs
			Modify_config_obfs
		elif [[ ${ssr_modify} == "7" ]]; then
			Set_config_protocol_param
			Modify_config_protocol_param
		elif [[ ${ssr_modify} == "8" ]]; then
			Set_config_speed_limit_per_con
			Modify_config_speed_limit_per_con
		elif [[ ${ssr_modify} == "9" ]]; then
			Set_config_speed_limit_per_user
			Modify_config_speed_limit_per_user
		elif [[ ${ssr_modify} == "10" ]]; then
			Set_config_method
			Set_config_protocol
			Set_config_obfs
			Set_config_protocol_param
			Set_config_speed_limit_per_con
			Set_config_speed_limit_per_user
			Modify_config_method
			Modify_config_protocol
			Modify_config_obfs
			Modify_config_protocol_param
			Modify_config_speed_limit_per_con
			Modify_config_speed_limit_per_user
		else
			echo -e "${Error}  qing shu ru zheng que de shu zi (1-9)" && exit 1
		fi
	fi
	Restart_SSR
}
#  xian shi   duo  port  yong hu  pei zhi 
List_multi_port_user(){
	user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
	[[ ${user_total} = "0" ]] && echo -e "${Error} Meiyou Faxian  duo  port  yong hu ，Qing jian cha !" && exit 1
	user_list_all=""
	for((integer = ${user_total}; integer >= 1; integer--))
	do
		user_port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
		user_password=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $2}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
		user_list_all=${user_list_all}" port : "${user_port}"  Pwd : "${user_password}"\n"
	done
	echo && echo -e " yong hu  zong shu  ${Green_font_prefix}"${user_total}"${Font_color_suffix}"
	echo -e ${user_list_all}
}
#  tian jia   duo  port  yong hu  pei zhi 
Add_multi_port_user(){
	Set_config_port
	Set_config_password
	sed -i "8 i \"        \"${ssr_port}\":\"${ssr_password}\"," ${config_user_file}
	sed -i "8s/^\"//" ${config_user_file}
	Add_iptables
	Save_iptables
	echo -e "${Info}  duo  port  yong hu  tian jia  Wan chen ${Green_font_prefix}[ port : ${ssr_port} ,  Pwd : ${ssr_password}]${Font_color_suffix} "
}
#  xiu gai   duo  port  yong hu  pei zhi 
Modify_multi_port_user(){
	List_multi_port_user
	echo && echo -e " qing  shu ru yao  xiu gai 的 yong hu  port "
	stty erase '^H' && read -p "( mo ren :  qu xiao ):" modify_user_port
	[[ -z "${modify_user_port}" ]] && echo -e "yi qu xiao ..." && exit 1
	del_user=`cat ${config_user_file}|grep '"'"${modify_user_port}"'"'`
	if [[ ! -z "${del_user}" ]]; then
		port="${modify_user_port}"
		password=`echo -e ${del_user}|awk -F ":" '{print $NF}'|sed -r 's/.*\"(.+)\".*/\1/'`
		Set_config_port
		Set_config_password
		sed -i 's/"'$(echo ${port})'":"'$(echo ${password})'"/"'$(echo ${ssr_port})'":"'$(echo ${ssr_password})'"/g' ${config_user_file}
		Del_iptables
		Add_iptables
		Save_iptables
		echo -e "${Inof}  duo  port  yong hu  xiu gai  Wan chen ${Green_font_prefix}[ old : ${modify_user_port}  ${password} ,  new : ${ssr_port}  ${ssr_password}]${Font_color_suffix} "
	else
		echo -e "${Error}  qing  shu ru zheng que de  port  !" && exit 1
	fi
}
#  shan chu   duo  port  yong hu  pei zhi 
Del_multi_port_user(){
	List_multi_port_user
	user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
	[[ "${user_total}" = "1" ]] && echo -e "${Error}  duo  port  yong hu  zhi you  1 ge ， bu neng shan chu  !" && exit 1
	echo -e " qing  shu ru yao  shan chu de yong hu  port "
	stty erase '^H' && read -p "( mo ren :  qu xiao ):" del_user_port
	[[ -z "${del_user_port}" ]] && echo -e "yi qu xiao ..." && exit 1
	del_user=`cat ${config_user_file}|grep '"'"${del_user_port}"'"'`
	if [[ ! -z ${del_user} ]]; then
		port=${del_user_port}
		Del_iptables
		Save_iptables
		del_user_determine=`echo ${del_user:((${#del_user} - 1))}`
		if [[ ${del_user_determine} != "," ]]; then
			del_user_num=$(sed -n -e "/${port}/=" ${config_user_file})
			del_user_num=$(expr $del_user_num - 1)
			sed -i "${del_user_num}s/,//g" ${config_user_file}
		fi
		sed -i "/${port}/d" ${config_user_file}
		echo -e "${Info}  duo  port  yong hu  shan chu  Wan chen ${Green_font_prefix} ${del_user_port} ${Font_color_suffix} "
	else
		echo "${Error}  qing  shu ru zheng que de  port  !" && exit 1
	fi
}
#  shou dong  xiu gai   yong hu  pei zhi 
Manually_Modify_Config(){
	SSR_installation_status
	port=`${jq_file} '.server_port' ${config_user_file}`
	vi ${config_user_file}
	if [[ -z "${now_mode}" ]]; then
		ssr_port=`${jq_file} '.server_port' ${config_user_file}`
		Del_iptables
		Add_iptables
	fi
	Restart_SSR
}
#  qie huan  port  mo shi 
Port_mode_switching(){
	SSR_installation_status
	if [[ -z "${now_mode}" ]]; then
		echo && echo -e "	 dang qian mo shi : ${Green_font_prefix}dan  port ${Font_color_suffix}" && echo
		echo -e " de que yao qie huan wei   duo  port  mo shi ？[y/N]"
		stty erase '^H' && read -p "( mo ren : n):" mode_yn
		[[ -z ${mode_yn} ]] && mode_yn="n"
		if [[ ${mode_yn} == [Yy] ]]; then
			port=`${jq_file} '.server_port' ${config_user_file}`
			Set_config_all
			Write_configuration_many
			Del_iptables
			Add_iptables
			Save_iptables
			Restart_SSR
		else
			echo && echo "	 yi  qu xiao ..." && echo
		fi
	else
		echo && echo -e "	 dang qian mo shi : ${Green_font_prefix} duo  port ${Font_color_suffix}" && echo
		echo -e " de que yao qie huan wei  dan port  mo shi ？[y/N]"
		stty erase '^H' && read -p "( mo ren : n):" mode_yn
		[[ -z ${mode_yn} ]] && mode_yn="n"
		if [[ ${mode_yn} == [Yy] ]]; then
			user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
			for((integer = 1; integer <= ${user_total}; integer++))
			do
				port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
				Del_iptables
			done
			Set_config_all
			Write_configuration
			Add_iptables
			Restart_SSR
		else
			echo && echo "	 yi  qu xiao ..." && echo
		fi
	fi
}
Start_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} ShadowsocksR  zheng zai yun xing  !" && exit 1
	/etc/init.d/ssr start
	check_pid
	[[ ! -z ${PID} ]] && View_User
}
Stop_SSR(){
	SSR_installation_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} ShadowsocksR  wei yun xing  !" && exit 1
	/etc/init.d/ssr stop
}
Restart_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/ssr stop
	/etc/init.d/ssr start
	check_pid
	[[ ! -z ${PID} ]] && View_User
}
View_Log(){
	SSR_installation_status
	[[ ! -e ${ssr_log_file} ]] && echo -e "${Error} ShadowsocksR ri zhi  wen jian  Bu cun zai  !" && exit 1
	echo && echo -e "${Tip}  an  ${Red_font_prefix}Ctrl+C${Font_color_suffix}  zhong zhi  cha kan  ri zhi " && echo
	tail -f ${ssr_log_file}
}
# Rui su
Configure_Server_Speeder(){
	echo && echo -e " ni yao zuo shen me ？
 ${Green_font_prefix}1.${Font_color_suffix}  Install  Rui su
 ${Green_font_prefix}2.${Font_color_suffix}  unInstall  Rui su
————————
 ${Green_font_prefix}3.${Font_color_suffix}  qi dong  Rui su
 ${Green_font_prefix}4.${Font_color_suffix}  ting zhi  Rui su
 ${Green_font_prefix}5.${Font_color_suffix}  chong qi  Rui su
 ${Green_font_prefix}6.${Font_color_suffix}  cha kan  Rui su  zhuang tai 
 
  zhu yi ： Rui su he LotServer bu neng tong shi  Install / qi dong ！" && echo
	stty erase '^H' && read -p "( mo ren :  qu xiao ):" server_speeder_num
	[[ -z "${server_speeder_num}" ]] && echo " yi  qu xiao ..." && exit 1
	if [[ ${server_speeder_num} == "1" ]]; then
		Install_ServerSpeeder
	elif [[ ${server_speeder_num} == "2" ]]; then
		Server_Speeder_installation_status
		Uninstall_ServerSpeeder
	elif [[ ${server_speeder_num} == "3" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} start
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "4" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} stop
	elif [[ ${server_speeder_num} == "5" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} restart
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "6" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} status
	else
		echo -e "${Error}  qing shu ru zheng que de shu zi (1-6)" && exit 1
	fi
}
Install_ServerSpeeder(){
	[[ -e ${Server_Speeder_file} ]] && echo -e "${Error} Rui su(Server Speeder)  yi  Install  !" && exit 1
	cd /root
	#借用91yun.rog的开心版Rui su
	wget -N --no-check-certificate https://raw.githubusercontent.com/91yun/serverspeeder/master/serverspeeder.sh
	[[ ! -e "serverspeeder.sh" ]] && echo -e "${Error} Rui su Install Jiao BenXia zai Shi bai !" && exit 1
	bash serverspeeder.sh
	sleep 2s
	PID=`ps -ef |grep -v grep |grep "serverspeeder" |awk '{print $2}'`
	if [[ ! -z ${PID} ]]; then
		rm -rf /root/serverspeeder.sh
		rm -rf /root/91yunserverspeeder
		rm -rf /root/91yunserverspeeder.tar.gz
		echo -e "${Info} Rui su(Server Speeder)  Install  Wan chen !" && exit 1
	else
		echo -e "${Error} Rui su(Server Speeder)  Install  Shi bai !" && exit 1
	fi
}
Uninstall_ServerSpeeder(){
	echo " que ding yao  unInstall  Rui su(Server Speeder)？[y/N]" && echo
	stty erase '^H' && read -p "( mo ren : n):" unyn
	[[ -z ${unyn} ]] && echo && echo " yi  qu xiao ..." && exit 1
	if [[ ${unyn} == [Yy] ]]; then
		chattr -i /serverspeeder/etc/apx*
		/serverspeeder/bin/serverSpeeder.sh uninstall -f
		echo && echo "Rui su(Server Speeder)  unInstall  Wan chen !" && echo
	fi
}
# LotServer
Configure_LotServer(){
	echo && echo -e " ni yao zuo shen me ？
 ${Green_font_prefix}1.${Font_color_suffix}  Install  LotServer
 ${Green_font_prefix}2.${Font_color_suffix}  unInstall  LotServer
————————
 ${Green_font_prefix}3.${Font_color_suffix}  qi dong  LotServer
 ${Green_font_prefix}4.${Font_color_suffix}  ting zhi  LotServer
 ${Green_font_prefix}5.${Font_color_suffix}  chong qi  LotServer
 ${Green_font_prefix}6.${Font_color_suffix}  cha kan  LotServer  zhuang tai 
 
  zhu yi ： Rui su he LotServer bu neng tong shi  Install / qi dong ！" && echo
	stty erase '^H' && read -p "( mo ren :  qu xiao ):" lotserver_num
	[[ -z "${lotserver_num}" ]] && echo " yi  qu xiao ..." && exit 1
	if [[ ${lotserver_num} == "1" ]]; then
		Install_LotServer
	elif [[ ${lotserver_num} == "2" ]]; then
		LotServer_installation_status
		Uninstall_LotServer
	elif [[ ${lotserver_num} == "3" ]]; then
		LotServer_installation_status
		${LotServer_file} start
		${LotServer_file} status
	elif [[ ${lotserver_num} == "4" ]]; then
		LotServer_installation_status
		${LotServer_file} stop
	elif [[ ${lotserver_num} == "5" ]]; then
		LotServer_installation_status
		${LotServer_file} restart
		${LotServer_file} status
	elif [[ ${lotserver_num} == "6" ]]; then
		LotServer_installation_status
		${LotServer_file} status
	else
		echo -e "${Error}  qing shu ru zheng que de shu zi (1-6)" && exit 1
	fi
}
Install_LotServer(){
	[[ -e ${LotServer_file} ]] && echo -e "${Error} LotServer  yi  Install  !" && exit 1
	#Github: https://github.com/0oVicero0/serverSpeeder_Install
	wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh"
	[[ ! -e "/tmp/appex.sh" ]] && echo -e "${Error} LotServer  Install Jiao BenXia zai Shi bai !" && exit 1
	bash /tmp/appex.sh 'install'
	sleep 2s
	PID=`ps -ef |grep -v grep |grep "appex" |awk '{print $2}'`
	if [[ ! -z ${PID} ]]; then
		echo -e "${Info} LotServer  Install  Wan chen !" && exit 1
	else
		echo -e "${Error} LotServer  Install  Shi bai !" && exit 1
	fi
}
Uninstall_LotServer(){
	echo " que ding yao  unInstall  LotServer？[y/N]" && echo
	stty erase '^H' && read -p "( mo ren : n):" unyn
	[[ -z ${unyn} ]] && echo && echo " yi  qu xiao ..." && exit 1
	if [[ ${unyn} == [Yy] ]]; then
		wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh" && bash /tmp/appex.sh 'uninstall'
		echo && echo "LotServer  unInstall  Wan chen !" && echo
	fi
}
# BBR
Configure_BBR(){
	echo && echo -e "   ni yao zuo shen me ？
	
 ${Green_font_prefix}1.${Font_color_suffix}  Install  BBR
————————
 ${Green_font_prefix}2.${Font_color_suffix}  qi dong  BBR
 ${Green_font_prefix}3.${Font_color_suffix}  ting zhi  BBR
 ${Green_font_prefix}4.${Font_color_suffix}  cha kan  BBR  zhuang tai " && echo
echo -e "${Green_font_prefix} [ Install 前  qing  zhu yi ] ${Font_color_suffix}
1.  Install  kai qi BBR， xu yao geng huan nei hei ， cun zai geng huan  Shi bai deng feng xiang ( chong qi hou wu fa kai ji )
2. ben Jiao Ben jin zhi chi  Debian / Ubuntu xi tong geng huan ，OpenVZ he Docker bu zhi chi geng huan nei hei
3. Debian geng huan nei hei guo cheng zhong  ti shi  [  shi fou  zhong zhi  unInstall  nei hei  ] ， qing  xuan ze  ${Green_font_prefix} NO ${Font_color_suffix}" && echo
	stty erase '^H' && read -p "( mo ren :  qu xiao ):" bbr_num
	[[ -z "${bbr_num}" ]] && echo " yi  qu xiao ..." && exit 1
	if [[ ${bbr_num} == "1" ]]; then
		Install_BBR
	elif [[ ${bbr_num} == "2" ]]; then
		Start_BBR
	elif [[ ${bbr_num} == "3" ]]; then
		Stop_BBR
	elif [[ ${bbr_num} == "4" ]]; then
		Status_BBR
	else
		echo -e "${Error}  qing shu ru zheng que de shu zi (1-4)" && exit 1
	fi
}
Install_BBR(){
	[[ ${release} = "centos" ]] && echo -e "${Error} 本Jiao Ben bu zhi chi  CentOS xi tong  Install  BBR !" && exit 1
	BBR_installation_status
	bash "${BBR_file}"
}
Start_BBR(){
	BBR_installation_status
	bash "${BBR_file}" start
}
Stop_BBR(){
	BBR_installation_status
	bash "${BBR_file}" stop
}
Status_BBR(){
	BBR_installation_status
	bash "${BBR_file}" status
}
# 其他功能
Other_functions(){
	echo && echo -e "   ni yao zuo shen me ？
	
  ${Green_font_prefix}1.${Font_color_suffix}  pei zhi  BBR
  ${Green_font_prefix}2.${Font_color_suffix}  pei zhi  Rui su(ServerSpeeder)
  ${Green_font_prefix}3.${Font_color_suffix}  pei zhi  LotServer(Rui su mu gong si)
   zhu yi ： Rui su/LotServer/BBR  bu zhi chi  OpenVZ！
   zhu yi ： Rui su/LotServer/BBR  bu neng gong cun ！
————————————
  ${Green_font_prefix}4.${Font_color_suffix}  yi jian feng jin  BT/PT/SPAM (iptables)
  ${Green_font_prefix}5.${Font_color_suffix} yi jian jie feng BT/PT/SPAM (iptables)
  ${Green_font_prefix}6.${Font_color_suffix} qie huan ShadowsocksR ri zhi  shu chu  mo shi 
  ——shuo ming：SSR mo ren zhi shu chu cuo wu  ri zhi ，ci xiang ke qie huan wei  shu chu xiang xi de fang wen  ri zhi " && echo
	stty erase '^H' && read -p "( mo ren :  qu xiao ):" other_num
	[[ -z "${other_num}" ]] && echo " yi  qu xiao ..." && exit 1
	if [[ ${other_num} == "1" ]]; then
		Configure_BBR
	elif [[ ${other_num} == "2" ]]; then
		Configure_Server_Speeder
	elif [[ ${other_num} == "3" ]]; then
		Configure_LotServer
	elif [[ ${other_num} == "4" ]]; then
		BanBTPTSPAM
	elif [[ ${other_num} == "5" ]]; then
		UnBanBTPTSPAM
	elif [[ ${other_num} == "6" ]]; then
		Set_config_connect_verbose_info
	else
		echo -e "${Error}  qing shu ru zheng que de shu zi  [1-6]" && exit 1
	fi
}
# 封禁 BT PT SPAM
BanBTPTSPAM(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ban_iptables.sh && chmod +x ban_iptables.sh && bash ban_iptables.sh banall
	rm -rf ban_iptables.sh
}
# 解封 BT PT SPAM
UnBanBTPTSPAM(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ban_iptables.sh && chmod +x ban_iptables.sh && bash ban_iptables.sh unbanall
	rm -rf ban_iptables.sh
}
Set_config_connect_verbose_info(){
	SSR_installation_status
	Get_User
	if [[ ${connect_verbose_info} = "0" ]]; then
		echo && echo -e " dang qian  ri zhi  mo shi : ${Green_font_prefix} jian dan  mo shi （ zhi  shu chu  cuo wu  ri zhi ）${Font_color_suffix}" && echo
		echo -e " de que yao qie huan wei  ${Green_font_prefix} xiang xi  mo shi （ shu chu  xiang xi lian jie  ri zhi + cuo wu  ri zhi ）${Font_color_suffix}？[y/N]"
		stty erase '^H' && read -p "( mo ren : n):" connect_verbose_info_ny
		[[ -z "${connect_verbose_info_ny}" ]] && connect_verbose_info_ny="n"
		if [[ ${connect_verbose_info_ny} == [Yy] ]]; then
			ssr_connect_verbose_info="1"
			Modify_config_connect_verbose_info
			Restart_SSR
		else
			echo && echo "	 yi  qu xiao ..." && echo
		fi
	else
		echo && echo -e " dang qian  ri zhi  mo shi : ${Green_font_prefix} xiang xi  mo shi （ shu chu  xiang xi lian jie  ri zhi + cuo wu  ri zhi ）${Font_color_suffix}" && echo
		echo -e " de que yao qie huan wei  ${Green_font_prefix} jian dan  mo shi （ zhi  shu chu  cuo wu  ri zhi ）${Font_color_suffix}？[y/N]"
		stty erase '^H' && read -p "( mo ren : n):" connect_verbose_info_ny
		[[ -z "${connect_verbose_info_ny}" ]] && connect_verbose_info_ny="n"
		if [[ ${connect_verbose_info_ny} == [Yy] ]]; then
			ssr_connect_verbose_info="0"
			Modify_config_connect_verbose_info
			Restart_SSR
		else
			echo && echo "	 yi  qu xiao ..." && echo
		fi
	fi
}
Update_Shell(){
	echo -e " dang qian ban ben wei  [ ${sh_ver} ]，Kai shi jian ce zui xin ban ben ..."
	sh_new_ver=$(wget --no-check-certificate -qO- "https://softs.fun/Bash/ssr.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1) && sh_new_type="softs"
	[[ -z ${sh_new_ver} ]] && sh_new_ver=$(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ssr.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1) && sh_new_type="github"
	[[ -z ${sh_new_ver} ]] && echo -e "${Error}  jian ce zui xin ban ben  Shi bai !" && exit 0
	if [[ ${sh_new_ver} != ${sh_ver} ]]; then
		echo -e " fa xian xin ban ben [ ${sh_new_ver} ]， shi fou  update ？[Y/n]"
		stty erase '^H' && read -p "( mo ren : y):" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Yy] ]]; then
			if [[ $sh_new_type == "softs" ]]; then
				wget -N --no-check-certificate https://softs.fun/Bash/ssr.sh && chmod +x ssr.sh
			else
				wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ssr.sh && chmod +x ssr.sh
			fi
			echo -e "Jiao Ben yi  update  wei zui xin ban ben [ ${sh_new_ver} ] !"
		else
			echo && echo "	 yi  qu xiao ..." && echo
		fi
	else
		echo -e " dang qian  yi shi zui xin ban ben[ ${sh_new_ver} ] !"
	fi
}
#  xian shi  菜 dan  zhuang tai 
menu_status(){
	if [[ -e ${config_user_file} ]]; then
		check_pid
		if [[ ! -z "${PID}" ]]; then
			echo -e "  dang qian  zhuang tai : ${Green_font_prefix} yi  Install ${Font_color_suffix}  and  ${Green_font_prefix} yi  qi dong ${Font_color_suffix}"
		else
			echo -e "  dang qian  zhuang tai : ${Green_font_prefix} yi  Install ${Font_color_suffix}  but  ${Red_font_prefix} no  qi dong ${Font_color_suffix}"
		fi
		now_mode=$(cat "${config_user_file}"|grep '"port_password"')
		if [[ -z "${now_mode}" ]]; then
			echo -e "  dang qian mo shi : ${Green_font_prefix}dan port ${Font_color_suffix}"
		else
			echo -e "  dang qian mo shi : ${Green_font_prefix} duo  port ${Font_color_suffix}"
		fi
	else
		echo -e "  dang qian  zhuang tai : ${Red_font_prefix}no Install ${Font_color_suffix}"
	fi
}
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} ben Jiao Ben bu zhi chi  dang qian xi tong  ${release} !" && exit 1
echo -e "  ShadowsocksR yi jian guan li Jiao Ben ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  ---- Toyo | doub.io/ss-jc42 ----

  ${Green_font_prefix}1.${Font_color_suffix}  Install  ShadowsocksR
  ${Green_font_prefix}2.${Font_color_suffix}  update  ShadowsocksR
  ${Green_font_prefix}3.${Font_color_suffix}  unInstall  ShadowsocksR
  ${Green_font_prefix}4.${Font_color_suffix}  Install  libsodium(chacha20)
————————————
  ${Green_font_prefix}5.${Font_color_suffix}  cha kan   zhang hao  xin xi 
  ${Green_font_prefix}6.${Font_color_suffix}  xian shi   lian jie  xin xi 
  ${Green_font_prefix}7.${Font_color_suffix}  she zhi   yong hu  pei zhi 
  ${Green_font_prefix}8.${Font_color_suffix}  shou dong   xiu gai  pei zhi 
  ${Green_font_prefix}9.${Font_color_suffix}  qie huan   port  mo shi 
————————————
 ${Green_font_prefix}10.${Font_color_suffix}  qi dong  ShadowsocksR
 ${Green_font_prefix}11.${Font_color_suffix}  ting zhi  ShadowsocksR
 ${Green_font_prefix}12.${Font_color_suffix}  chong qi  ShadowsocksR
 ${Green_font_prefix}13.${Font_color_suffix}  cha kan  ShadowsocksR  ri zhi 
————————————
 ${Green_font_prefix}14.${Font_color_suffix} qi ta gong neng 
 ${Green_font_prefix}15.${Font_color_suffix}  sheng ji Jiao Ben
 "
menu_status
echo && stty erase '^H' && read -p " qing shu ru shu zi  [1-15]：" num
case "$num" in
	1)
	Install_SSR
	;;
	2)
	Update_SSR
	;;
	3)
	Uninstall_SSR
	;;
	4)
	Install_Libsodium
	;;
	5)
	View_User
	;;
	6)
	View_user_connection_info
	;;
	7)
	Modify_Config
	;;
	8)
	Manually_Modify_Config
	;;
	9)
	Port_mode_switching
	;;
	10)
	Start_SSR
	;;
	11)
	Stop_SSR
	;;
	12)
	Restart_SSR
	;;
	13)
	View_Log
	;;
	14)
	Other_functions
	;;
	15)
	Update_Shell
	;;
	*)
	echo -e "${Error}  qing shu ru zheng que de shu zi  [1-15]"
	;;
esac