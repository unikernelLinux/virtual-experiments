#!/bin/bash

set -x

dnf -y update
dnf -y install automake autoconf sed make supermin gcc flex bison \
	elfutils-libelf-devel bc hostname perl openssl-devel git dropbear \
	msr-tools wget dnf-plugins-core bzip2 curl xz

pushd /src/ukl

# Modern git won't let us interact with the repo as root when it is likely owned by a user
git config --global safe.directory '*'

#reset to a pristine state
pushd linux
git checkout ukl-main-5.14
git reset --hard HEAD
popd

# build the standard redis
git reset --hard HEAD
autoreconf -i
./configure --with-program=redis --enable-bypass --enable-use-ret
make -j`nproc` vmlinuz
mv vmlinuz /kernels/vmlinuz.ukl-byp
make clean

#Now build the deep shortcut
pushd linux
git checkout ukl-main-5.14-sc
popd
pushd redis
rm -rf stamp-redis-dir redis
make stamp-redis-dir
pushd redis # not a typo, we have ukl/redis/redis now that stamp-redis-dir is complete
git checkout redis-ukl-sc
popd
popd
./configure --with-program=redis --enable-bypass --enable-use-ret --enable-shortcuts
make -j`nproc` vmlinuz
cp vmlinuz /kernels/vmlinuz.ukl-sc

# Ensure we reset to origial state
pushd redis
make distclean-local
popd
pushd linux
git checkout ukl-main-5.14
popd
make clean

popd

if [ ! -d init-tools ]; then
	git clone https://github.com/unikernelLinux/init-tools.git
fi

pushd init-tools
./buildinitrd.sh ukl-initrd
cp ./ukl-initrd.cpio.xz /kernels
popd
popd
