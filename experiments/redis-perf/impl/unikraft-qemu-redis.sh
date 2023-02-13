#!/bin/bash

# verbose output
set -x

source ../common/set-cpus.sh
source ../common/network.sh
source ../common/redis.sh
source ../common/qemu.sh

IMAGES=$(pwd)/images/
BASEIP=172.190.0
NETIF=unikraft0
mkdir -p rawdata results

create_bridge $NETIF $BASEIP

kill_qemu
dnsmasq_pid=$(run_dhcp $NETIF $BASEIP)

function cleanup {
	# kill all children (evil)
	kill_dhcp $dnsmasq_pid
	kill_qemu
	pkill -P $$
	delete_bridge $NETIF
}

trap "cleanup" EXIT

RESULTS=results/unikraft-qemu.csv
echo "operation	throughput" > $RESULTS

for j in {1..10}
do
	LOGGET=rawdata/unikraft-qemu-redis-get-${j}.json
	LOGSET=rawdata/unikraft-qemu-redis-set-${j}.json

	taskset -c ${CPU1} qemu-guest \
		-i data/redis.cpio \
		-k ${IMAGES}/unikraft+mimalloc.kernel \
		-a "netdev.ipv4_addr=${BASEIP}.2 netdev.ipv4_gw_addr=${BASEIP}.1 netdev.ipv4_subnet_mask=255.255.255.0 -- /redis.conf" -m 1024 -p ${CPU2} \
		-b ${NETIF} -x

	# make sure that the server has properly started
	sleep 8

	#ip=`cat $(pwd)/dnsmasq.log | \
		#grep "dnsmasq-dhcp: DHCPACK(${NETIF})" | \
		#tail -n 1 | awk  '{print $3}'`

	# benchmark
	benchmark_redis_server ${BASEIP}.2 6379

	parse_redis_results $LOGGET $LOGSET $RESULTS

	# stop server
	kill_qemu
done
