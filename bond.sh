#!/bin/bash

#20190320110041——OK
#定义变量
centos6_version_number=$(awk '{print $3}' /etc/system-release| awk -F"." '{print $1}')
centos7_version_number=$(awk '{print $4}' /etc/system-release| awk -F"." '{print $1}')
ip_addr=$(ip route show | grep "src" | awk '{print $9}')
gate_way=$(ip route show | egrep via | awk '{print $3}')
network_card=$(ls /etc/sysconfig/network-scripts/ifcfg-[e]* | awk -F"-" '{print $NF}' | sort -ur)
dns="61.139.2.69"
bondcard="bond0"

#公共函数
echo_out(){
    echo  "----------------------------------------------------"
    echo -e "\033[33;42m "$1" \033[0m"
    echo  "----------------------------------------------------"
}

Variable(){
echo_out "获取本机网卡名为：$network_card"
echo_out "获取本机的地址为：$ip_addr"
echo_out "获取本机的网关为：$gate_way"
read -p "请输入第一个网卡名：" name1 
read -p "请输入第二个网卡名：" name2
read -p "请确认输入要绑定的ip地址：" ipa 
read -p "请确认输入将设置的网关地址 " gateway
echo "network_card_1: $name1"
echo "network_card_2: $name2"
echo "ipaddr: $ipa"
echo "gateway: $gateway"
read -p "请确认输入的信息是否正确，确定按Y/y,退出按N/n: " signal
}

centos6_config_bond(){
Variable
if [ "$signal" == "Y" ] || [ "$signal" == "y" ];then
cd /etc/sysconfig/network-scripts/
cat > ifcfg-$bondcard <<eof
DEVICE=$bondcard
ONBOOT=yes
BOOTPROTO=none
IPADDR=$ipa
PREFIX=24
GATEWAY=$gateway
DNS1=$dns
BONDING_OPTS="mode=1 miimon=100"
eof

cat > ifcfg-$name1<<eof
DEVICE=$name1
TYPE=Ehternet
ONBOOT=yes
MASTER=$bondcard
SLAVE=yes
eof

cat > ifcfg-$name2 <<eof
DEVICE=$name2
TYPE=Ehternet
ONBOOT=yes
MASTER=$bondcard
SLAVE=yes
eof

cd /etc/modprobe.d/
[ -f ${bondcard}.conf ] || touch ${bondcard}.conf
echo "alias bond0 bonding" > ${bondcard}.conf
echo "ifenslave bond0 $name1 $name2" >> /etc/rc.d/rc.local
[ $? == 0 ] && /etc/init.d/network restart
ls -d /sys/class/net/$bondcard/ && echo "bond0 Configuration success!!"
ifconfig

elif [ "$signal" == "N" ] || [ "$signal" == "n" ];then
	exit
else
	echo_out "请选择Y/y或N/n进行输入！！"
fi
}


centos7_config_bond(){
Variable
if [ "$signal" == Y ] || [ "$signal" == y ];then
nmcli connection add type bond con-name "$bondcard" ifname "$bondcard" mode 1
nmcli connection modify "$bondcard" ipv4.addresses "$ipa"/24 ipv4.gateway "$gateway" ipv4.dns $dns
nmcli connection modify "$bondcard" ipv4.method manual
nmcli connection add type bond-slave ifname "$name1" master "$bondcard"
nmcli connection add type bond-slave ifname "$name2" master "$bondcard"
nmcli connection up "$bondcard"
sleep 3
nmcli connection up bond-slave-$name1
nmcli connection up bond-slave-$name2
sleep 2
cat /proc/net/bonding/"$bondcard"
[ $? == 0 ] && systemctl restart network.service
ifconfig
echo_out "$network_card"
read -p "以上哪一张网卡在做bond之前配置了IP地址，请选择网卡名进行输入移除： " netcard
ncad=`echo_out "$network_card" | grep "$netcard"`
if [ ! -z $ncad ];then
cd /etc/sysconfig/network-scripts/
[ -d ifcfg_bak ] || mkdir ifcfg_bak
mv ifcfg-$netcard ifcfg_bak/
echo_out "网卡名称为：$netcard 配置文件被成功移除！"
else
echo_out "你输入的网卡名称系统中没有，请确认后再输入！"
fi
elif [ "$signal" == N ] || [ "$signal" == n ];then
	exit
else
	echo_out "请选择Y/y或N/n进行输入！！"
fi
}

#调用函数
if [ "$centos6_version_number" == 6 ];then
        echo_out "本机是版本6的系统！！"
        centos6_config_bond
elif [ "$centos7_version_number" == 7 ];then
        echo_out "本机是版本7的系统"
        centos7_config_bond
else
        echo_out "请检查系统版本是否为6或7！！"
        exit
fi
