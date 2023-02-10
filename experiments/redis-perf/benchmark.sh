#!/bin/bash

# makes sure to run host setup
../common/setup-host.sh

mkdir rawdata results

# run benchmarks
./impl/ukl-qemu-redis.sh
./impl/osv-qemu-redis.sh
./impl/lupine-qemu-redis.sh
./impl/microvm-qemu-redis.sh
./impl/unikraft-qemu-redis.sh
