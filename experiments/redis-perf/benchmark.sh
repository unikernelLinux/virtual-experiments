#!/bin/bash

# makes sure to run host setup
../common/setup-host.sh

mkdir rawdata results

# run benchmarks
./impl/unikraft-qemu-redis.sh
./impl/ukl-qemu-redis.sh
./impl/lupine-qemu-redis.sh
./impl/microvm-qemu-redis.sh
