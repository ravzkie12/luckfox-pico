#!/bin/bash

ROOTFS_NAME="rootfs-alpine.tar.gz"
DEVICE_NAME="pico-mini-b"

while getopts ":f:d:" opt; do
  case ${opt} in
    f) ROOTFS_NAME="${OPTARG}" ;;
    d) DEVICE_NAME="${OPTARG}" ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 1
      ;;
  esac
done

DEVICE_ID="6"
case $DEVICE_NAME in
  pico-mini-b) DEVICE_ID="6" ;;
  pico-plus) DEVICE_ID="7" ;;
  pico-pro-max) DEVICE_ID="8" ;;
  *)
    echo "Invalid device: ${DEVICE_NAME}."
    exit 1
    ;;
esac

rm -rf sdk/sysdrv/custom_rootfs/
mkdir -p sdk/sysdrv/custom_rootfs/
cp "$ROOTFS_NAME" sdk/sysdrv/custom_rootfs/

pushd sdk || exit

pushd tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf/ || exit
source env_install_toolchain.sh
popd || exit

rm -rf .BoardConfig.mk
echo "$DEVICE_ID" | ./build.sh lunch
echo "export RK_CUSTOM_ROOTFS=../sysdrv/custom_rootfs/$ROOTFS_NAME" >> .BoardConfig.mk
echo "export RK_BOOTARGS_CMA_SIZE=\"1M\"" >> .BoardConfig.mk

# Workaround: build.sh при custom rootfs пишет файлы в стандартные подкаталоги
# (bin/, etc/profile.d/, etc/init.d/, usr/bin/ и т.д.), не создавая их —
# минимальный Alpine-rootfs их не содержит. Создаём заранее, сразу после распаковки.
# Патчим project/build.sh напрямую — build.sh это симлинк на него, sed -i иначе его сломает.
sed -i '/^\ttar xf \$rootfs_tarball -C \$RK_PROJECT_PACKAGE_ROOTFS_DIR$/a\\tmkdir -p $RK_PROJECT_PACKAGE_ROOTFS_DIR/{bin,sbin,etc/profile.d,etc/init.d,usr/bin,usr/sbin,usr/lib,usr/share,lib}' project/build.sh

./build.sh uboot
./build.sh kernel
./build.sh driver
./build.sh env
./build.sh firmware
./build.sh save

popd || exit

rm -rf output
mkdir -p output
cp sdk/output/image/update.img "output/$DEVICE_NAME-sysupgrade.img"
