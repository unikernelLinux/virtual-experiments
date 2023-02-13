#!/bin/bash

# verbose output
set -x

source ../common/set-cpus.sh
source ../common/network.sh
source ../common/redis.sh

IMAGES=$(pwd)/images

NETIF=tux0
RESULTS=results/microvm-qemu.csv
echo "operation	throughput" > $RESULTS
mkdir -p rawdata

create_bridge $NETIF $BASEIP
killall -9 qemu-system-x86
pkill -9 qemu-system-x86

function cleanup {
	# kill all children (evil)
	delete_bridge $NETIF
	rm ${IMAGES}/redis.ext2.disposible
	killall -9 qemu-system-x86
	pkill -9 qemu-system-x86
	pkill -P $$
}

trap "cleanup" EXIT

for j in {1..10}
do
	LOGGET=rawdata/microvm-qemu-redis-get-${j}.json
	LOGSET=rawdata/microvm-qemu-redis-set-${j}.json

	cp ${IMAGES}/redis.ext2 ${IMAGES}/redis.ext2.disposible

	taskset -c ${CPU1} qemu-guest \
		-k ${IMAGES}/generic-qemu.kernel \
		-d ${IMAGES}/redis.ext2.disposible \
		-a "root=/dev/vda rw console=ttyS0 init=/guest_start.sh redis-server" \
                -m 1024 -p ${CPU2}\
		-b ${NETIF} -x

	# make sure that the server has properly started
	sleep 3

	# benchmark
	benchmark_redis_server ${BASEIP}.2 6379

	parse_redis_results $LOGGET $LOGSET $RESULTS

	# stop server
	killall -9 qemu-system-x86
	pkill -9 qemu-system-x86
	rm ${IMAGES}/redis.ext2.disposible
done
