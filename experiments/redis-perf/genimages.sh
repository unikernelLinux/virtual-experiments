#!/bin/bash

set -x

source ../common/network.sh
source ../common/build.sh
source ../common/set-cpus.sh

BUILDDIR=..
GUESTSTART=$(pwd)/data/guest_start.sh
IMAGES=$(pwd)/images

rm -rf $IMAGES
mkdir -p $IMAGES

# ========================================================================
# Generate UKL VM Images
# ========================================================================

build_ukl

# ========================================================================
# Generate Unikraft VM images
# ========================================================================

unikraft_eurosys21_build redis mimalloc $IMAGES

# ========================================================================
# Generate Lupine VM images + redis ext2 rootfs
# ========================================================================

LUPINEDIR=${BUILDDIR}/.lupine

build_lupine

KERNELS="${LUPINEDIR}/Lupine-Linux/kernelbuild/"
# compressed one for QEMU
LUPINE_KVM_KPATH="${KERNELS}/lupine-djw-kml-qemu++redis/vmlinuz-4.0.0-kml"
GENERIC_KVM_KPATH="${KERNELS}/microvm++redis/vmlinuz-4.0.0"

cp $LUPINE_KVM_KPATH ${IMAGES}/lupine-qemu.kernel
cp $GENERIC_KVM_KPATH ${IMAGES}/generic-qemu.kernel

pushd ${LUPINEDIR}/Lupine-Linux/
# various patches...
cp ${GUESTSTART} ./scripts/guest_start.sh
sed -i -e "s/192.168.100/${BASEIP}/" ./scripts/guest_net.sh
sed -i -e "s/seek=20G/seek=500M/" ./scripts/image2rootfs.sh

# build image
./scripts/image2rootfs.sh redis 5.0.4-alpine ext2

# idempotence
git checkout ./scripts/image2rootfs.sh
git checkout ./scripts/guest_net.sh
git checkout ./scripts/guest_start.sh
popd

mv ${LUPINEDIR}/Lupine-Linux/redis.ext2 ${IMAGES}/redis.ext2

modprobe loop
mkdir -p /mnt/redis-tmp
mount -o loop ${IMAGES}/redis.ext2 /mnt/redis-tmp
cp ./data/redis.conf /mnt/redis-tmp
umount /mnt/redis-tmp
rm -rf /mnt/redis-tmp

# ========================================================================
# Generate OSv VM image
# ========================================================================

CONTAINER=osv-tmp
docker pull hlefeuvre/osv
docker run --rm --privileged --name=$CONTAINER \
			--cpuset-cpus="${CPU1}-${CPU4}" \
			-v $(pwd)/data:/data-imported \
			-dt hlefeuvre/osv
docker exec -it $CONTAINER cp /data-imported/redis.conf \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/always-show-logo/#always-show-logo/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/replica-serve-stale/#replica-serve-stale/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/supervised/#supervised/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/replica-lazy-flush/#replica-lazy-flush/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/aof-load-truncated/#aof-load-truncated/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/aof-use-rdb-preamble/#aof-use-rdb-preamble/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/dynamic-hz/#dynamic-hz/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/stream-node-/#stream-node-/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/list-max-ziplist-size -2/list-max-ziplist-entries 512/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/list-compress-depth 0/list-max-ziplist-value 64/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/hll-sparse-max-byte/#hll-sparse-max-byte/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/rdb-save-incremental-fsync/#rdb-save-incremental-fsync/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/latency-monitor-threshold/#latency-monitor-threshold/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/replica/slave/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER sed -i -e "s/lazyfree-/#lazyfree-/" \
		   /root/osv/apps/redis-memonly/redis.conf
docker exec -it $CONTAINER bash -c \
	"cd /root/osv &&./scripts/build -j4 fs=zfs image=redis-memonly"
mkdir -p ${IMAGES}/osv/root/
docker cp ${CONTAINER}:/root/osv/ ${IMAGES}/osv/root/
docker container stop $CONTAINER
docker rm -f $CONTAINER

cp ${IMAGES}/osv/root/osv/build/release/usr.img ${IMAGES}/osv-qemu.img
cp ${IMAGES}/osv/root/osv/build/release/kernel.elf ${IMAGES}/osv-fc.kernel

