#!/bin/bash

VERSION_MAJOR="6"
VERSION_MINOR="6"
NO_EDDSA=0
SUFFIX="${VERSION_MAJOR}.${VERSION_MINOR}"
#if ! [[ -z "${GITHUB_SHA}" ]]; then
#    SUFFIX="${SUFFIX}.${GITHUB_SHA}"
#fi

mkdir -p build_release
mkdir -p release
rm -rf -- release/*
cd build_release

PICO_SDK_PATH="${PICO_SDK_PATH:-../../pico-sdk}"
board_dir=${PICO_SDK_PATH}/src/boards/include/boards
SECURE_BOOT_PKEY="${SECURE_BOOT_PKEY:-../../ec_private_key.pem}"

for board in "$board_dir"/*
do
    board_name="$(basename -- "$board" .h)"
    rm -rf -- ./*
    # MinSizeRel: RP2350 firmware runs from RAM, and -O3 with EdDSA leaves too little heap to boot
    PICO_SDK_PATH="${PICO_SDK_PATH}" cmake .. -DPICO_BOARD=$board_name -DSECURE_BOOT_PKEY=${SECURE_BOOT_PKEY} -DENABLE_EDDSA=1 -DCMAKE_BUILD_TYPE=MinSizeRel
    make -j`nproc`
    mv pico_fido2.uf2 ../release/pico_fido2_$board_name-$SUFFIX.uf2
done
