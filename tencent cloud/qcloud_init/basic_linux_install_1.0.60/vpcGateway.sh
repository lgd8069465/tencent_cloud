#!/bin/bash
echo "----------------------------------------------------"
echo "          `date`"

echo "(1)ip_forward config......"
file="/etc/sysctl.conf"
grep -i "^net\.ipv4\.ip_forward.*" $file &>/dev/null && sed -i 's/net\.ipv4\.ip_forward.*/net\.ipv4\.ip_forward = 1/' $file || echo "net.ipv4.ip_forward = 1"  >> $file
echo 1 >/proc/sys/net/ipv4/ip_forward 
[ `cat /proc/sys/net/ipv4/ip_forward` -eq 1 ] && echo "-->ip_forward:Success" ||  echo "-->ip_forward:Fail"

echo "(2)Iptables set......"
iptables -t nat -A POSTROUTING -j MASQUERADE && echo "-->nat:Success" || echo "-->nat:Fail"
iptables -t mangle -A POSTROUTING -p tcp -j TCPOPTSTRIP --strip-options timestamp && echo "-->mangle:Success" || echo "-->mangle:Fail"

echo "(3)nf_conntrack config......"
echo 262144 >  /sys/module/nf_conntrack/parameters/hashsize
[ `cat /sys/module/nf_conntrack/parameters/hashsize` -eq 262144 ] && echo "-->hashsize:Success" ||  echo "-->hashsize:Fail"

echo 1048576 > /proc/sys/net/netfilter/nf_conntrack_max
[ `cat /proc/sys/net/netfilter/nf_conntrack_max` -eq 1048576 ] && echo  "-->nf_conntrack_max:Success" ||  echo  "-->nf_conntrack_max:Fail"

echo 10800 >/proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established
[ `cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established` -eq 10800 ] && echo  "-->nf_conntrack_tcp_timeout_established:Success" ||  echo  "-->nf_conntrack_tcp_timeout_established:Fail"

#echo 7200 >/proc/sys/net/netfilter/nf_conntrack_tcp_timeout_unacknowledged
#[ `cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_unacknowledged` -eq 7200 ] && echo  "-->nf_conntrack_tcp_timeout_unacknowledged:Success" ||  echo  "-->nf_conntrack_tcp_timeout_unacknowledged:Fail"

echo 1200 >/proc/sys/net/netfilter/nf_conntrack_tcp_timeout_time_wait
[ `cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_time_wait` -eq 1200 ] && echo  "-->nf_conntrack_tcp_timeout_time_wait:Success" ||  echo  "-->nf_conntrack_tcp_timeout_time_wait:Fail"

