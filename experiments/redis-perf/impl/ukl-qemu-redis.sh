#!/bin/bash

# verbose output
set -x

NETIF=ukl0
mkdir -p rawdata

IMAGES=$(pwd)/images

source ../common/set-cpus.sh
source ../common/network.sh
source ../common/redis.sh

create_bridge $NETIF $BASEIP
killall -9 qemu-system-x86
pkill -9 qemu-system-x86

function cleanup {
	# kill all children (evil)
	delete_bridge $NETIF
	killall -9 qemu-system-x86
	pkill -9 qemu-system-x86
	pkill -P $$
}

trap "cleanup" EXIT

for UKL_CONFIG in "byp" "sc"
do
	RESULTS=results/ukl-${UKL_CONFIG}-qemu.csv
	echo "operation	throughput" > $RESULTS

	for j in {1..10}
	do
		LOG=rawdata/ukl-${UKL_CONFIG}-qemu-redis-${j}.txt
		touch $LOG

		taskset -c ${CPU1} qemu-guest \
			-k ${IMAGES}/vmlinuz.ukl-${UKL_CONFIG} \
			-i ${IMAGES}/ukl-initrd.cpio.xz \
			-a "console=ttyS0 net.ifnames=0 biosdevname=0 nowatchdog nopti nosmap nosmep ip=${BASEIP}.2:::255.255.255.0::eth0:none nokaslr selinux=0 root=/dev/ram0 init=/init" \
                	-m 1024 -p ${CPU2} \
			-b ${NETIF} -x

		# make sure that the server has properly started
		sleep 15

		# benchmark
		benchmark_redis_server ${BASEIP}.2 6379

		parse_redis_results $LOG $RESULTS

		# stop server
		killall -9 qemu-system-x86
		pkill -9 qemu-system-x86
	done
done
