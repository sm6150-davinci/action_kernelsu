#!/usr/bin/env sh
#
# GNU General Public License v3.0
# Copyright (C) 2023 MoChenYa mochenya20070702@gmail.com
#

WORKDIR="$(pwd)"

# ZyClang
ZYCLANG_DLINK="https://github.com/ZyCromerZ/Clang/releases/download/18.0.0-20230902-release/Clang-18.0.0-20230902.tar.gz"
ZYCLANG_DIR="$WORKDIR/ZyClang/bin"

# Kernel Source
KERNEL_GIT="https://github.com/sm6150-davinci/kernel_xiaomi_sm6150.git"
KERNEL_BRANCHE="perf"
KERNEL_DIR="$WORKDIR/Perf"

# Anykernel3
ANYKERNEL3_GIT="https://github.com/sm6150-davinci/AnyKernel3.git"
ANYKERNEL3_BRANCHE="master"

# Build
DEVICES_CODE="davinci"
DEVICE_DEFCONFIG="vendor/davinci_perf_defconfig"
DEVICE_DEFCONFIG_FILE="$KERNEL_DIR/arch/arm64/configs/$DEVICE_DEFCONFIG"
IMAGE="$KERNEL_DIR/out/arch/arm64/boot/Image.gz"
DTB="$KERNEL_DIR/out/arch/arm64/boot/dtb.img"
DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"

export KBUILD_BUILD_USER=helliscloser
export KBUILD_BUILD_HOST=GitHubCI

msg() {
	echo
	echo -e "\e[1;32m$*\e[0m"
	echo
}

cd $WORKDIR

# Download ZyClang
msg " • 🌸 Work on $WORKDIR 🌸"
msg " • 🌸 Cloning Toolchain 🌸 "
mkdir -p ZyClang
aria2c -s16 -x16 -k1M $ZYCLANG_DLINK -o ZyClang.tar.gz
tar -C ZyClang/ -zxvf ZyClang.tar.gz
rm -rf ZyClang.tar.gz

# CLANG LLVM VERSIONS
CLANG_VERSION="$($ZYCLANG_DIR/clang --version | head -n 1)"
LLD_VERSION="$($ZYCLANG_DIR/ld.lld --version | head -n 1)"

msg " • 🌸 Cloning Kernel Source 🌸 "
git clone --depth=1 $KERNEL_GIT -b $KERNEL_BRANCHE $KERNEL_DIR
cd $KERNEL_DIR

msg " • 🌸 Patching KernelSU 🌸 "
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
            echo "CONFIG_KPROBES=y" >> $DEVICE_DEFCONFIG_FILE
            echo "CONFIG_HAVE_KPROBES=y" >> $DEVICE_DEFCONFIG_FILE
            echo "CONFIG_KPROBE_EVENTS=y" >> $DEVICE_DEFCONFIG_FILE
KSU_GIT_VERSION=$(cd KernelSU && git rev-list --count HEAD)
KERNELSU_VERSION=$(($KSU_GIT_VERSION + 10000 + 200))
msg " • 🌸 KernelSU version: $KERNELSU_VERSION 🌸 "

# PATCH KERNELSU
msg " • 🌸 Applying patches || "

apply_patchs () {
for patch_file in $WORKDIR/patchs/*.patch
	do
	patch -p1 < "$patch_file"
done
}
apply_patchs

sed -i "/CONFIG_LOCALVERSION=\"/s/.$/-KSU-$KERNELSU_VERSION\"/" $DEVICE_DEFCONFIG_FILE

# BUILD KERNEL
msg " • 🌸 Started Compilation 🌸 "

args="PATH=$ZYCLANG_DIR:$PATH \
ARCH=arm64 \
SUBARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
CC=clang \
NM=llvm-nm \
CXX=clang++ \
AR=llvm-ar \
LD=ld.lld \
STRIP=llvm-strip \
OBJDUMP=llvm-objdump \
OBJSIZE=llvm-size \
READELF=llvm-readelf \
HOSTAR=llvm-ar \
HOSTLD=ld.lld \
HOSTCC=clang \
HOSTCXX=clang++ \
LLVM=1 \
LLVM_IAS=1"

# LINUX KERNEL VERSION
rm -rf out
make O=out $args $DEVICE_DEFCONFIG
KERNEL_VERSION=$(make O=out $args kernelversion | grep "4.14")
msg " • 🌸 LINUX KERNEL VERSION : $KERNEL_VERSION 🌸 "
make O=out $args -j"$(nproc --all)"

msg " • 🌸 Packing Kernel 🌸 "
cd $WORKDIR
git clone --depth=1 $ANYKERNEL3_GIT -b $ANYKERNEL3_BRANCHE $WORKDIR/Anykernel3
cd $WORKDIR/Anykernel3
cp $IMAGE .
cp $DTB $WORKDIR/Anykernel3/dtb
cp $DTBO .

# PACK FILE
time=$(TZ='Africa/Cairo' date +"%Y-%m-%d %H:%M:%S")
cairo_time=$(TZ='Africa/Cairo' date +%Y%m%d%H)
ZIP_NAME="PerfnonDynamic-$KERNEL_VERSION-KernelSU-$KERNELSU_VERSION.zip"
find ./ * -exec touch -m -d "$time" {} \;
zip -r9 $ZIP_NAME *
mkdir -p $WORKDIR/out && cp *.zip $WORKDIR/out

cd $WORKDIR/out
echo "
### Perf-Non-Dynamic KERNEL With/Without KERNELSU
1. **Time** : $(TZ='Africa/Cairo' date +"%Y-%m-%d %H:%M:%S") # Cario TIME
2. **Device Code** : $DEVICES_CODE
3. **LINUX Version** : $KERNEL_VERSION
4. **KERNELSU Version**: $KERNELSU_VERSION
5. **CLANG Version**: $CLANG_VERSION
6. **LLD Version**: $LLD_VERSION
" > RELEASE.md
echo "
### Perf-Non-Dynamic KERNEL With/Without KERNELSU
1. **Time** : $(TZ='Africa/Cairo' date +"%Y-%m-%d %H:%M:%S") # Cario TIME
2. **Device Code** : $DEVICES_CODE
3. **LINUX Version** : $KERNEL_VERSION
4. **KERNELSU Version**: $KERNELSU_VERSION
5. **CLANG Version**: ZyC clang version 18.0.0
6. **LLD Version**: LLD 18.0.0
" > telegram_message.txt
echo "Perf-Non-DynamicKernel-$KERNEL_VERSION" > RELEASETITLE.txt
cat RELEASE.md
cat telegram_message.txt
cat RELEASETITLE.txt
msg "• 🌸 Done! 🌸 "
