#!/bin/bash

BUILDDIR=../
LUPINEDIR=${BUILDDIR}/.lupine
UKLDIR=${BUILDDIR}/.ukl

build_ukl() {
	mkdir -p ${UKLDIR}

	if [ ! -d ${UKLDIR}/ukl ]; then
		pushd ${UKLDIR}
		git clone https://github.com/unikernelLinux/ukl
		pushd ukl
		git submodule update --init
		popd
		popd

	fi

	docker pull fedora:36
	CONTAINER=ukl-builder
	docker stop $CONTAINER
	docker rm -f $CONTAINER
	ABSUKL=`readlink -f ${UKLDIR}`
	docker run --rm --privileged --name=${CONTAINER} -v ${ABSUKL}:/src -v ${IMAGES}:/kernels -dit fedora:36 /bin/bash
	docker cp ../common/build-ukl.sh ${CONTAINER}:/
	docker exec -it $CONTAINER /build-ukl.sh

	docker stop $CONTAINER
}

build_lupine() {
    mkdir -p ${LUPINEDIR}

    if [ ! -d "${LUPINEDIR}/Lupine-Linux" ]; then
	    pushd ${LUPINEDIR}
	    git clone https://github.com/unikernelLinux/Lupine-Linux.git
	    pushd Lupine-Linux
	    git submodule update --init
	    make build-env-image
	    pushd load_entropy
	    make
	    popd
	    popd
	    popd
    fi

    if [ ! -d "${LUPINEDIR}/Lupine-Linux/kernelbuild" ]; then
	pushd ${LUPINEDIR}/Lupine-Linux

	# build qemu/kvm version
	cp configs/lupine-djw-kml.config configs/lupine-djw-kml-qemu.config
	echo "CONFIG_PCI=y" >> configs/lupine-djw-kml-qemu.config
	echo "CONFIG_PCI=y" >> configs/microvm.config
	echo "CONFIG_VIRTIO_BLK_SCSI=y" >> configs/lupine-djw-kml-qemu.config
	echo "CONFIG_VIRTIO_BLK_SCSI=y" >> configs/microvm.config
	echo "CONFIG_VIRTIO_PCI_LEGACY=y" >> configs/lupine-djw-kml-qemu.config
	echo "CONFIG_VIRTIO_PCI_LEGACY=y" >> configs/microvm.config
	echo "CONFIG_VIRTIO_PCI=y" >> configs/lupine-djw-kml-qemu.config
	echo "CONFIG_VIRTIO_PCI=y" >> configs/microvm.config
	echo "CONFIG_VGA_ARB_MAX_GPUS=16" >> configs/microvm.config

	./scripts/build-with-configs.sh configs/lupine-djw-kml-qemu.config \
						configs/apps/nginx.config
	./scripts/build-with-configs.sh configs/lupine-djw-kml-qemu.config \
						configs/apps/redis.config
	./scripts/build-with-configs.sh nopatch configs/microvm.config \
						configs/apps/nginx.config
	./scripts/build-with-configs.sh nopatch configs/microvm.config \
						configs/apps/redis.config

	# just in case :)
	make build-env-image

	# build normal lupine kernels
	# TODO it would be nice to build this with GCC 6.3.0 to be absolutely fair
	./scripts/build-kernels.sh

	# idempotence
	git checkout scripts/build-kernels.sh
	popd
    fi
}

unikraft_eurosys21_build() {
    unikraft_eurosys21_build_wvmm $1 $2 $3 kvm
}

unikraft_eurosys21_build_wvmm() {
    CONTAINER=uk-tmp-nginx
    # kill zombies
    docker container stop $CONTAINER
    docker rm -f $CONTAINER
    sleep 6
    docker pull hlefeuvre/unikraft-eurosys21:latest
    docker run --rm --privileged --name=$CONTAINER \
			-dt hlefeuvre/unikraft-eurosys21
    docker exec -it $CONTAINER bash -c \
	"cd app-${1} && cp configs/${2}.conf .config"
    docker exec -it $CONTAINER bash -c \
	"cd app-${1} && make prepare && make -j"
    docker cp ${CONTAINER}:/root/workspace/apps/app-${1}/build/app-${1}_${4}-x86_64 \
		${3}/unikraft+${2}.kernel
    # special case: for solo5, also copy hvt
    if [ "$4" = "solo5" ]; then
        docker cp ${CONTAINER}:/root/workspace/apps/app-${1}/build/solo5-hvt \
            ${IMAGES}/solo5_hvt
    fi
    docker container stop $CONTAINER
    docker rm -f $CONTAINER
    sleep 6
}

