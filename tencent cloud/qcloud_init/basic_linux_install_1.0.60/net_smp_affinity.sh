#!/bin/bash
##used to bind virtio-input interrupt to last cpu

echo "--------------------------------------------"
date

get_highest_mask()
{
	cpu_nums=$1
	if [ $cpu_nums -gt 32 ]; then
		mask_tail=""
		mask_low32="00000000"
		idx=$((cpu_nums/32))
		cpu_reset=$((cpu_nums-idx*32))

		if [ $cpu_reset -eq 0 ]; then
			mask="80000000"
			for((i=2;i<=idx;i++))
			do
				mask="$mask,$mask_low32"
			done
		else
			for ((i=1;i<=idx;i++))
			do
				mask_tail="$mask_tail,$mask_low32"
			done
			mask_head_num=$((1<<(cpu_reset-1)))
			mask=`printf "%x%s" $mask_head_num $mask_tail`
		fi

	else
		mask_num=$((1<<(cpu_nums-1)))
		mask=`printf "%x" $mask_num`
	fi
	echo $mask
}

input_irq_bind()
{
	netQueueCount=`cat /proc/interrupts  | grep -i ".*virtio.*input.*" | wc -l`
	irqSet=`cat /proc/interrupts  | grep -i ".*virtio.*input.*" | awk -F ':' '{print $1}'`
	i=0
	for irq in $irqSet
	do
		cpunum=$((i%cpuCount+1))
		mask=`get_highest_mask $cpunum`
		echo $mask > /proc/irq/$irq/smp_affinity
		echo "[input]bind irq $irq with mask 0x$mask affinity"
		((i++))
	done
}

output_irq_bind()
{
	netQueueCount=`cat /proc/interrupts  | grep -i ".*virtio.*input.*" | wc -l`
	irqSet=`cat /proc/interrupts  | grep -i ".*virtio.*output.*" | awk -F ':' '{print $1}'`
	i=0
	for irq in $irqSet
	do
		cpunum=$((i%cpuCount+1))
		mask=`get_highest_mask $cpunum`
		echo $mask > /proc/irq/$irq/smp_affinity
		echo "[output]bind irq $irq with mask 0x$mask affinity"
		((i++))
	done
}

ethConfig()
{
	ethSet=`ls -d /sys/class/net/eth*`
	for ethd in $ethSet
	do
		eth=`basename $ethd`
		pre_max=`ethtool -l $eth 2>/dev/null | grep -i "combined" | head -n 1 | awk '{print $2}'`
		cur_max=`ethtool -l $eth 2>/dev/null | grep -i "combined" | tail -n 1 | awk '{print $2}'`

		[ $? -eq 0 ] || continue #ethtool error

		if [ $pre_max -ne $cur_max ]; then
			ethtool -L $eth combined $pre_max
			echo "Set [$eth] Current Combined to <$pre_max>"
		fi
	done
}

smartnic_bind()
{
    irqSet=`cat /proc/interrupts  | grep "LiquidIO.*rxtx" | awk -F ':' '{print $1}'`
    i=0
    for irq in $irqSet
    do
        cpunum=$((i%cpuCount+1))
        mask=`get_highest_mask $cpunum`
        echo $mask > /proc/irq/$irq/smp_affinity
        echo "[smartnic]bind irq $irq with mask 0x$mask affinity"
        ((i++))
    done
}

set_net_affinity()
{
	ps ax | grep -v grep | grep -q irqbalance && killall irqbalance 2>/dev/null
    cat /proc/interrupts  | grep "LiquidIO.*rxtx" &>/dev/null
    if [ $? -eq 0 ]; then #smartnic
        smartnic_bind
    else
        ethConfig
        input_irq_bind
        output_irq_bind
    fi
}

cpuCount=`cat /proc/cpuinfo |grep processor |wc -l`
if [ $cpuCount -eq 0 ] ;then
	echo "machine cpu count get error!"
	exit 0
elif [ $cpuCount -eq 1 ]; then
	echo "machine only have one cpu, needn't set affinity for net interrupt"
	exit 0
fi

set_net_affinity
